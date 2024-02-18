// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:resource_storage/resource_storage.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synchronized/synchronized.dart';

import 'resource.dart';
import 'resource_config.dart';
import 'storage/memory_resource_storage.dart';
import 'util/cache_duration.dart';
import 'util/network_bound_resource.dart';
import 'util/utils.dart';

/// Cached resource implementation based on [NetworkBoundResource]
/// to follow the single source of truth principle.
///
/// Usage:
///
/// ```dart
/// final repo = CachedResource<String, Wallet>.persistent(
///     'user_wallet_info', // storage name, like table name in a database
///     fetch: _api.getWalletById,
///     decode: Wallet.fromJson,
///     cacheDuration: const CacheDuration(minutes: 30),
///     );
///
/// void listenForWalletUpdates() {
///   subscription = repo.asStream(_walletId)
///       .listen((resource) {
///         if (resource.hasData) {
///           final wallet = resource.data;
///           // ...
///         } else if (resource.isLoading) {
///          // ...
///         } else if (res.isError) {
///          // ...
///         }
///       });
/// }
///
/// //and
/// void onRefresh() => repo.invalidate(_walletId);
///
/// //or just
/// void handleWallet() async {
///   final wallet = await repo.first(_walletId);
///   //handle wallet...
/// }
/// ```
class CachedResource<K, V> {
  /// Creates Cached resource with provided [storage].
  ///
  /// [fetch] callback need to be set if you receive value of resource from
  /// any external source (Call to a server API, some local calculation, etc).
  ///
  /// If [fetch] not set then there is only [putValue] and [updateCachedValue]
  /// methods to set/update value of the resource.
  ///
  /// [cacheDuration] used to check if cache is stale. If cache is stale
  /// then new fetch request will be triggered.
  /// If [fetch] is not set then [cacheDuration] is ignored.
  /// Set [CacheDuration.neverStale] to never stale cache.
  ///
  /// By default, the last emitted success value is keeping in the internal
  /// cache to emit [Resource.loading] state as soon as possible. To disable
  /// the internal cache set [internalCacheEnabled] = false.
  ///
  CachedResource({
    required ResourceStorage<K, V> storage,
    FetchCallable<K, V>? fetch,
    CacheDuration<K, V> cacheDuration = const CacheDuration.neverStale(),
    bool internalCacheEnabled = true,
  })  : _fetch = fetch,
        _storage = storage,
        _internalCacheEnabled = internalCacheEnabled,
        _cacheDuration = cacheDuration;

  /// Creates CachedResource with In-Memory storage.
  ///
  /// Implementation of memory storage will be resolved by
  /// [ResourceConfig.inMemoryStorageFactory] and can be changed using
  /// [ResourceConfig.setup]. By default [MemoryResourceStorage] is used.
  ///
  /// Also see [CachedResource.new].
  ///
  CachedResource.inMemory(
    String cacheName, {
    FetchCallable<K, V>? fetch,
    CacheDuration<K, V> cacheDuration = const CacheDuration.neverStale(),
  }) : this(
          storage: ResourceConfig.instance.inMemoryStorageFactory
              .createStorage<K, V>(
            storageName: cacheName,
            logger: ResourceConfig.instance.logger,
          ),
          fetch: fetch,
          cacheDuration: cacheDuration,
        );

  /// Creates CachedResource with persistent storage.
  ///
  /// Implementation of persistent storage will be resolved by
  /// [ResourceConfig.persistentStorageFactory] and required to be set using
  /// [ResourceConfig.setup] before first usage.
  /// If factory was not set - StateError throws.
  ///
  /// [decode] argument completely depends of storage implementation.
  /// For example, if we use a storage that stores value as a json then
  /// we need to provide fromJson factory, usually something like
  /// `decode: User.fromJson`.
  ///
  /// Also see [CachedResource.new].
  ///
  CachedResource.persistent(
    String cacheName, {
    FetchCallable<K, V>? fetch,
    StorageDecoder<V>? decode,
    CacheDuration<K, V> cacheDuration = const CacheDuration.neverStale(),
    StorageExecutor? executor,
  }) : this(
          storage: ResourceConfig.instance
              .requirePersistentStorageProvider()
              .createStorage<K, V>(
                storageName: cacheName,
                decode: decode ?? defaultStorageDecoder<V>(),
                executor: executor,
                logger: ResourceConfig.instance.logger,
              ),
          fetch: fetch,
          cacheDuration: cacheDuration,
        );

  /// Creates CachedResource with secure storage.
  ///
  /// Implementation of secure storage will be resolved by
  /// [ResourceConfig.secureStorageFactory] and required to be set using
  /// [ResourceConfig.setup] before first usage.
  /// If factory was not set - StateError throws.
  ///
  /// [decode] argument completely depends of storage implementation.
  /// For example, if we use a storage that stores value as a json then
  /// we need to provide fromJson factory, usually something like
  /// `decode: User.fromJson`.
  ///
  /// By default, for secure resource we set [internalCacheEnabled] = false
  /// to not keep emitted values in the internal cache.
  ///
  /// Also see [CachedResource.new].
  ///
  CachedResource.secure(
    String cacheName, {
    FetchCallable<K, V>? fetch,
    StorageDecoder<V>? decode,
    CacheDuration<K, V> cacheDuration = const CacheDuration.neverStale(),
    bool internalCacheEnabled = false,
  }) : this(
          storage: ResourceConfig.instance
              .requireSecureStorageProvider()
              .createStorage<K, V>(
                storageName: cacheName,
                decode: decode ?? defaultStorageDecoder<V>(),
                logger: ResourceConfig.instance.logger,
              ),
          fetch: fetch,
          cacheDuration: cacheDuration,
          internalCacheEnabled: internalCacheEnabled,
        );

  final ResourceStorage<K, V> _storage;
  final FetchCallable<K, V>? _fetch;
  final CacheDuration<K, V> _cacheDuration;
  final bool _internalCacheEnabled;
  final _resources = <K, NetworkBoundResource<K, V>>{};
  final _lock = Lock();

  /// Creates cold (defer) stream of the resource. On subscribe it triggers
  /// resource to load from cache or external source ([_fetch] callback)
  /// if cache is stale.
  ///
  /// Set [forceReload] = true to force resource reloading from external source
  /// even if cache is not stale yet.
  Stream<Resource<V>> asStream(K key, {bool forceReload = false}) =>
      Rx.defer(() async* {
        final resource = await _ensureResource(key);
        yield* resource.asStream(forceReload: forceReload);
      });

  /// Triggers resource to load (from cache or external if cache is stale)
  /// and returns not stale resource or error.
  ///
  /// Set [forceReload] = true to force resource reloading from external source
  /// even if cache is not stale yet.
  ///
  /// Note: You never get [Resource.loading] state here
  /// unless [allowLoadingState] set true.
  Future<Resource<V>> get(
    K key, {
    bool forceReload = false,
    bool allowLoadingState = false,
  }) =>
      asStream(key, forceReload: forceReload)
          .where((r) => r.isNotLoading || (allowLoadingState && r.hasData))
          .first;

  /// Make cache stale.
  /// Also triggers resource reloading if [forceReload] is true (by default)
  /// Returns future that completes after reloading completed with success
  /// or error.
  Future<void> invalidate(K key, {bool forceReload = true}) async {
    final resource = await _ensureResource(key);
    return resource.invalidate(forceReload: forceReload);
  }

  /// Applies [edit] function to cached value and emit as new success value
  /// If [notifyOnNull] set as true then will emit success(null) in case
  /// if there was a cached value but edit function returned null
  Future<void> updateCachedValue(
    K key,
    V? Function(V? value) edit, {
    bool notifyOnNull = false,
  }) async {
    final resource = await _ensureResource(key);
    return resource.updateCachedValue(edit, notifyOnNull: notifyOnNull);
  }

  /// Returns cached value if exists
  /// Set [synchronized] to false if you need to call this function
  /// inside [FetchCallable] or [updateCachedValue]
  Future<V?> getCachedValue(K key, {bool synchronized = true}) async {
    final resource = await _ensureResource(key);
    return resource.getCachedValue(synchronized: synchronized);
  }

  /// Puts new value to cache and emits Resource.success(value)
  Future<void> putValue(K key, V value) async {
    final resource = await _ensureResource(key);
    return resource.putValue(value);
  }

  /// Closes all active subscriptions for the resource assigned to [key]
  /// and deletes its cached value from storage
  Future<void> remove(K key) => _lock.synchronized(() async {
        await _resources[key]?.close();
        _resources.remove(key);
        await _storage.remove(key);
      });

  /// Closes all active subscriptions to resource of any key that was opened
  /// before and completely clears resource storage
  Future<void> clearAll() => _lock.synchronized(() async {
        await Future.wait(_resources.values.map((r) => r.close()));
        _resources.clear();
        await _storage.clear();
      });

  Future<NetworkBoundResource<K, V>> _ensureResource(K key) =>
      _lock.synchronized(() async {
        final resource = _resources.putIfAbsent(
          key,
          () => NetworkBoundResource<K, V>(
            key,
            fetch: _fetch,
            cacheDuration: _cacheDuration,
            storage: _storage,
            internalCacheEnabled: _internalCacheEnabled,
            logger: ResourceConfig.instance.logger,
          ),
        );
        return resource;
      });
}
