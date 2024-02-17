// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:resource_storage/resource_storage.dart';
import 'package:synchronized/synchronized.dart';

import 'resource.dart';
import 'resource_config.dart';
import 'storage/memory_resource_storage.dart';
import 'util/network_bound_resource.dart';

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
///     cacheDuration: const Duration(minutes: 30),
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
  /// [cacheDuration] - is a simple way to set cache duration. If resource
  /// is requested after [cacheDuration] cached value will be treated
  /// as stale and new fetch request will be triggered.
  /// If [fetch] is not set or if [cacheDurationResolver] is set then
  /// [cacheDuration] is ignored.
  ///
  /// Use [cacheDurationResolver] if you need a custom logic for dynamically
  /// resolving cache duration by resource value.
  ///
  CachedResource({
    required ResourceStorage<K, V> storage,
    FetchCallable<K, V>? fetch,
    Duration? cacheDuration,
    CacheDurationResolver<K, V>? cacheDurationResolver,
  })  : _fetch = fetch,
        _storage = storage,
        _cacheDurationResolver = (cacheDurationResolver ??
            (_, __) => cacheDuration ?? Duration.zero);

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
    Duration? cacheDuration,
    CacheDurationResolver<K, V>? cacheDurationResolver,
  }) : this(
          storage: ResourceConfig.instance.inMemoryStorageFactory
              .createStorage<K, V>(
            storageName: cacheName,
            logger: ResourceConfig.instance.logger,
          ),
          fetch: fetch,
          cacheDuration: cacheDuration,
          cacheDurationResolver: cacheDurationResolver,
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
    Duration? cacheDuration,
    CacheDurationResolver<K, V>? cacheDurationResolver,
    StorageExecutor? executor,
  }) : this(
          storage: ResourceConfig.instance
              .requirePersistentStorageProvider()
              .createStorage<K, V>(
                storageName: cacheName,
                decode: decode,
                executor: executor,
                logger: ResourceConfig.instance.logger,
              ),
          fetch: fetch,
          cacheDuration: cacheDuration,
          cacheDurationResolver: cacheDurationResolver,
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
  /// Also see [CachedResource.new].
  ///
  CachedResource.secure(
    String cacheName, {
    FetchCallable<K, V>? fetch,
    StorageDecoder<V>? decode,
    Duration? cacheDuration,
    CacheDurationResolver<K, V>? cacheDurationResolver,
  }) : this(
          storage: ResourceConfig.instance
              .requireSecureStorageProvider()
              .createStorage<K, V>(
                storageName: cacheName,
                decode: decode,
                logger: ResourceConfig.instance.logger,
              ),
          fetch: fetch,
          cacheDuration: cacheDuration,
          cacheDurationResolver: cacheDurationResolver,
        );

  final ResourceStorage<K, V> _storage;
  final FetchCallable<K, V>? _fetch;
  final CacheDurationResolver<K, V> _cacheDurationResolver;
  final _resources = <K, NetworkBoundResource<K, V>>{};
  final _lock = Lock();

  /// Triggers resource to load (from cache or external if cache is stale)
  /// and returns hot stream of resource.
  ///
  /// Set [forceReload] = true to force resource reloading from external source
  /// even if cache is not stale yet.
  ///
  Stream<Resource<V>> asStream(K key, {bool forceReload = false}) async* {
    final resource = await _ensureResource(key);
    yield* resource.asStream(forceReload: forceReload);
  }

  /// Triggers resource to load (from cache or external if cache is stale)
  /// and returns resource.
  ///
  /// Set [forceReload] = true to force resource reloading from external source
  /// even if cache is not stale yet.
  ///
  Future<Resource<V>> get(K key, {bool forceReload = false}) =>
      asStream(key, forceReload: forceReload)
          .where((r) => r.isNotLoading)
          .first;

  /// Make cache stale.
  /// Also triggers resource reloading if [forceReload] is true (by default)
  /// Returns future that completes after reloading completed with success
  /// or error.
  Future<void> invalidate(K key, {bool forceReload = true}) async {
    final resource = await _ensureResource(key);
    return resource.invalidate(forceReload);
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
            cacheDurationResolver: _cacheDurationResolver,
            storage: _storage,
            logger: ResourceConfig.instance.logger,
          ),
        );
        return resource;
      });
}
