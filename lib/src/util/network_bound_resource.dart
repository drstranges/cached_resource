// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:resource_storage/resource_storage.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synchronized/synchronized.dart';

import '../resource.dart';
import 'cache_duration.dart';

/// Callback to load resource from external source, usually from the network
/// by [key] ([key] == [_resourceKey])
typedef FetchCallable<K, V> = Future<V> Function(K key);

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
  /// 1. Immediately emits [Resource.loading] state for new subscriber.
  ///    If [internalCacheEnabled] then loading state contains
  ///    the last known value.
  /// 2. Retrieve cached data from [storage].
  /// 3. If [fetch] callback is not provided then emits Resource.success
  ///    with cached data and breaks.
  /// 4. If [fetch] callback is provided and cached data exists
  ///    then [cacheDurationResolver] is called to resolve cache duration.
  /// 5. If cached data is not stale yet - emits [Resource.success] with
  ///    cached data and breaks.
  /// 5. If cached data is stale - [Resource.loading] emits and
  ///    [fetch] callback executes to fetch fresh data.
  /// 6. Regarding the result of [fetch], emits [Resource.success]
  ///    or [Resource.error]
  ///
  NetworkBoundResource(
    this._resourceKey, {
    required ResourceStorage<K, V> storage,
    required CacheDuration<K, V> cacheDuration,
    FetchCallable<K, V>? fetch,
    ResourceLogger? logger,
    TimestampProvider timestampProvider = const TimestampProvider(),
    bool internalCacheEnabled = true,
  })  : _logger = logger,
        _fetch = fetch,
        _cacheDuration = cacheDuration,
        _storage = storage,
        _timestampProvider = timestampProvider,
        _last = _InternalCache(enabled: internalCacheEnabled);

  final K _resourceKey;
  final FetchCallable<K, V>? _fetch;
  final CacheDuration<K, V> _cacheDuration;
  final ResourceStorage<K, V> _storage;
  final ResourceLogger? _logger;

  /// Set custom timestamp provider if you need it in tests
  final TimestampProvider _timestampProvider;

  final _subject = PublishSubject<Resource<V>>();
  final _lock = Lock();
  final _InternalCache _last;

  bool _isLoading = false;
  bool _shouldReload = false;

  /// Whether there is at least one subscriber using [asStream].
  bool get hasListener => _subject.hasListener;

  /// Creates cold (defer) stream of the resource. On subscribe, it triggers
  /// resource to load from cache or external source ([_fetch] callback)
  /// if cache is stale.
  ///
  /// Set [forceReload] = true to force resource reloading from external source
  /// even if cache is not stale yet.
  Stream<Resource<V>> asStream({bool forceReload = false}) => Rx.defer(() {
        _requestLoading(forceReload: forceReload);
        return _subject.startWith(Resource.loading(_last.value)).distinct();
      });

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
        _emit(Resource.success(newValue));
      } else if (cache != null) {
        // newValue is null, so we need to remove old one from cache
        await _storage.remove(_resourceKey);
        if (notifyOnNull) _emit(Resource.success(null));
      }
    });
  }

  void _emit(Resource<V> resource) {
    _last.value = resource.data;
    _subject.add(resource);
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
        _emit(Resource.success(value));
      });

  /// Removes resource associated to [_resourceKey] from cache
  Future<void> clearCache() {
    clearInternalCache();
    return _storage.remove(_resourceKey);
  }

  void clearInternalCache() => _last.clear();

  /// Makes cache stale.
  ///
  /// Also, if [reloadIfListened] (by default) then for each resource that
  /// currently is listened triggers reloading. If [emitLoadingOnReload]
  /// then emits loading state firstly.
  ///
  /// Returns future that completes after reloading finished with success
  /// or error.
  Future<void> invalidate({
    bool reloadIfListened = true,
    bool emitLoadingOnReload = false,
  }) async {
    // don't clear cache for offline usage, just override store time
    await _overrideStoreTime(0);

    if (reloadIfListened && hasListener) {
      if (emitLoadingOnReload) {
        _emit(Resource.loading(_last.value));
      }
      await asStream(forceReload: true)
          .where((event) => event.isNotLoading)
          .first;
    }
  }

  /// Closes all active subscriptions.
  /// New subscriptions will fail after this call.
  Future<void> close() => _subject.close();

  void _requestLoading({bool forceReload = false}) async {
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
        _emit(Resource.success(cache?.value));
      });

  Future<void> _loadFromExternal() => _lock.synchronized(() async {
        assert(_fetch != null);
        // get value from cache
        final cache = await _storage.getOrNull(_resourceKey);

        if (_last.value != cache?.value) {
          _emit(Resource.loading(cache?.value));
        }

        // if cache is stale then need to reload resource from external source
        bool shouldReload =
            _shouldReload || (cache != null && _isCacheStale(cache));

        // no need to perform another requested loading as fetch was not called yet
        _shouldReload = false;

        if (cache != null && !shouldReload) {
          // There is no external fetch callback, so cache is only source
          // or there is not stale cache and forceReload not requested
          _emit(Resource.success(cache.value));
          return;
        }

        // fetch new value from external source
        final fetchStream =
            _fetch!(_resourceKey).asStream().asyncMap((data) async {
          //store new value in the cache before emitting
          await _storage.put(_resourceKey, data);
          _last.value = data;
          return Resource.success(data);
        }).onErrorReturnWith((error, trace) {
          _logger?.trace(LoggerLevel.error,
              'Error loading resource by key [$_resourceKey]', error, trace);
          return Resource.error(
            'Error loading resource by key [$_resourceKey]',
            error: error,
            stackTrace: trace,
            data: cache?.value,
          );
        });

        return _subject.addStream(fetchStream);
      });

  bool _isCacheStale(CacheEntry<V> cache) =>
      _cacheDuration.isCacheStale(_resourceKey, cache, _timestampProvider);

  Future<void> _overrideStoreTime(int storeTime) async {
    _lock.synchronized(() async {
      final cache = await _storage.getOrNull(_resourceKey);
      if (cache != null) {
        await _storage.put(_resourceKey, cache.value, storeTime: storeTime);
      }
    });
  }
}

/// Internal fast cache for last emitted value.
/// Can be disabled for security reason to not keep a value in memory
class _InternalCache<V> {
  _InternalCache({required this.enabled});

  final bool enabled;
  V? _cache;

  V? get value => _cache;

  set value(V? newValue) {
    if (enabled) {
      _cache = newValue;
    }
  }

  void clear() {
    _cache = null;
  }
}
