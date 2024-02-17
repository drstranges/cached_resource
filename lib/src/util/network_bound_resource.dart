// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:resource_storage/resource_storage.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synchronized/synchronized.dart';

import '../resource.dart';

/// Callback to load resource from external source, usually from the network
/// by [key] ([key] == [_resourceKey])
typedef FetchCallable<K, V> = Future<V> Function(K key);

/// Callback to resolve cache duration for each cached value.
typedef CacheDurationResolver<K, V> = Duration Function(K key, V value);

/// Implementation of NetworkBoundResource to follow the single source of truth
/// principle.
///
/// Usage:
///
/// ```dart
///   final userResource = NetworkBoundResource(
///     userId,
///     cacheDurationResolver: (_, __) => const Duration(minutes: 15),
///     storage: MemoryResourceStorage(),
///     fetch: userApi.getUserById,
///   );
///
/// void init() {
///   subscription = userResource.asStream().listen((resource) {
///       if (resource.hasData) {
///         final user = resource.data;
///         // ...
///       } else if (resource.isLoading) {
///        // ...
///       } else if (res.isError) {
///        // ...
///       }
///     });
/// }
///
/// void onRefresh() => userResource.invalidate();
///
/// ```
class NetworkBoundResource<K, V> {
  /// Creates NetworkBoundResource for [_resourceKey].
  ///
  /// Each time when [NetworkBoundResource.asStream] called the next sequence
  /// is executed:
  ///
  /// 1. Retrieve cached data from [storage]
  ///
  /// 2. If cached data exists then [cacheDurationResolver] is called to resolve
  /// cache duration.
  ///
  /// 3. If cached data is not stale yet - [Resource.success] emits
  ///
  /// 4. If cached data is stale - [Resource.loading] emits and
  /// [fetch] callback executes to fetch fresh data
  /// and then [Resource.success] emits
  ///
  NetworkBoundResource(
    this._resourceKey, {
    required CacheDurationResolver<K, V> cacheDurationResolver,
    required ResourceStorage<K, V> storage,
    FetchCallable<K, V>? fetch,
    Logger? logger,
    TimestampProvider timestampProvider = const TimestampProvider(),
  })  : _logger = logger,
        _fetch = fetch,
        _cacheDurationResolver = cacheDurationResolver,
        _storage = storage,
        _timestampProvider = timestampProvider;

  final K _resourceKey;
  final FetchCallable<K, V>? _fetch;
  final CacheDurationResolver<K, V> _cacheDurationResolver;
  final ResourceStorage<K, V> _storage;
  final Logger? _logger;

  /// Set custom timestamp provider if you need it in tests
  final TimestampProvider _timestampProvider;

  final _subject = PublishSubject<Resource<V>>();
  final _lock = Lock();

  bool _isLoading = false;
  bool _shouldReload = false;

  /// Triggers resource to load (from cache or external if cache is stale)
  /// and returns hot stream of resource.
  ///
  /// Set [forceReload] = true to force resource reloading from external source
  /// even if cache is not stale yet.
  ///
  Stream<Resource<V>> asStream({bool forceReload = false}) {
    _requestLoading(forceReload: forceReload);
    return _subject.distinct();
  }

  /// Applies [edit] function to cached value and emit as new success value
  /// If [notifyOnNull] set as true then will emit success(null) in case
  /// if there was a cached value but edit function returned null
  Future<void> updateCachedValue(
    V? Function(V? value) edit, {
    bool notifyOnNull = false,
  }) async {
    return _lock.synchronized(() async {
      final cache = await _storage.getOrNull(_resourceKey);
      final newValue = edit(cache?.value);

      if (newValue != null) {
        await _storage.put(
          _resourceKey,
          newValue,
          storeTime: cache?.storeTime ?? 0,
        );
        _subject.add(Resource.success(newValue));
      } else if (cache != null) {
        // newValue is null, so we need to remove old one from cache
        await _storage.remove(_resourceKey);
        if (notifyOnNull) _subject.add(Resource.success(null));
      }
    });
  }

  /// Returns cached value if exists
  /// Set [synchronized] to false if you need to call this function
  /// inside [FetchCallable] or [updateCachedValue]
  Future<V?> getCachedValue({bool synchronized = true}) {
    return synchronized
        ? _lock.synchronized(() => _getCachedValue())
        : _getCachedValue();
  }

  Future<V?> _getCachedValue() async {
    final cache = await _storage.getOrNull(_resourceKey);
    return cache?.value;
  }

  /// Puts new value in cache and emits Resource.success(value)
  Future<void> putValue(V value) => _lock.synchronized(() async {
        await _storage.put(_resourceKey, value);
        _subject.add(Resource.success(value));
      });

  /// Removes resource associated to [_resourceKey] from cache
  Future<void> clearCache() => _storage.remove(_resourceKey);

  /// Make cache stale.
  /// Also triggers resource reloading if [forceReload] is true (by default)
  /// Returns future that completes after reloading finished with success
  /// or error.
  Future<void> invalidate([bool forceReload = true]) async {
    // don't clear cache for offline usage, just override store time
    await _overrideStoreTime(0);
    if (forceReload) {
      await asStream(forceReload: true)
          .where((event) => event.isNotLoading)
          .first;
    }
  }

  /// Closes all active subscriptions.
  /// New subscriptions will fail after this call.
  Future<void> close() => _subject.close();

  void _requestLoading({
    bool forceReload = false,
  }) async {
    if (forceReload) {
      _shouldReload = true;
    }
    if (_isLoading) {
      // don't need to start new loading if there is already loading
    } else {
      _isLoading = true;
      if (_fetch == null) {
        await _loadFromCache();
      } else {
        await _loadFromExternal();
      }
      _isLoading = false;

      if (_shouldReload) {
        _requestLoading(forceReload: true);
      }
    }
  }

  Future<void> _loadFromCache() => _lock.synchronized(() async {
        // No need to perform another requested loading as fetch was not called yet
        _shouldReload = false;
        final cache = await _storage.getOrNull(_resourceKey);

        // Try always starting with loading value
        // to pass through _subject.distinct()
        _subject
          ..add(Resource.loading(cache?.value))
          ..add(Resource.success(cache?.value));
      });

  Future<void> _loadFromExternal() => _lock.synchronized(() async {
        assert(_fetch != null);
        // get value from cache
        final cache = await _storage.getOrNull(_resourceKey);

        // try always starting with loading value
        // to pass through _subject.distinct()
        final resource = Resource.loading(cache?.value);
        _subject.add(resource);

        // if cache is stale then need to reload resource from external source
        bool shouldReload =
            _shouldReload || (cache != null && _isCacheStale(cache));

        // no need to perform another requested loading as fetch was not called yet
        _shouldReload = false;

        if (cache != null && !shouldReload) {
          // There is no external fetch callback, so cache is only source
          // or there is not stale cache and forceReload not requested
          final resource = Resource.success(cache.value);
          _subject.add(resource);
          return;
        }

        // fetch new value from external source
        final fetchStream = _fetch!(_resourceKey)
            .asStream()
            .asyncMap((data) async {
              //store new value in the cache before emitting
              await _storage.put(_resourceKey, data);
              return data;
            })
            .map((data) => Resource.success(data))
            .onErrorReturnWith((error, trace) {
              _logger?.trace(
                  LoggerLevel.error,
                  'Error loading resource by key [$_resourceKey]',
                  error,
                  trace);
              return Resource.error(
                'Error loading resource by key [$_resourceKey]',
                error: error,
                stackTrace: trace,
                data: cache?.value,
              );
            });

        return _subject.addStream(fetchStream);
      });

  bool _isCacheStale(CacheEntry<V> cache) {
    if (cache.storeTime <= 0) {
      // seems like cached time was reset, so resource is stale
      return true;
    }
    final cacheDuration =
        _cacheDurationResolver(_resourceKey, cache.value).inMilliseconds;
    final now = _timestampProvider.getTimestamp();
    return cache.storeTime < now - cacheDuration;
  }

  Future<void> _overrideStoreTime(int storeTime) async {
    _lock.synchronized(() async {
      final cache = await _storage.getOrNull(_resourceKey);
      if (cache != null) {
        await _storage.put(_resourceKey, cache.value, storeTime: storeTime);
      }
    });
  }
}
