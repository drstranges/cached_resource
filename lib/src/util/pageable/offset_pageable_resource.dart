// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:cached_resource/cached_resource.dart';
import 'package:collection/collection.dart';

import '../utils.dart';

/// Default page size for [OffsetPageableResource]
const defaultResourcePageSize = 15;

/// Default negative shift in offset value during page loading.
const defaultIntersectionCount = 1;

/// Callback to load items from the external source (server api, etc.)
typedef LoadPageCallback<K, V> = Future<List<V>> Function(
    K key, int offset, int limit);

/// Cached resource that allows pageable loading.
class OffsetPageableResource<K, V> {
  /// Creates pageable resource with custom storage
  OffsetPageableResource({
    required ResourceStorage<K, OffsetPageableData<V>> storage,
    required Future<List<V>> Function(K, int, int) loadPage,
    CacheDuration<K, OffsetPageableData<V>> cacheDuration =
        const CacheDuration.neverStale(),
    OffsetPageableDataFactory<V>? pageableDataFactory,
    this.pageSize = defaultResourcePageSize,
    this.intersectionCount = defaultIntersectionCount,
    ResourceLogger? logger,
  })  : assert(intersectionCount >= 0),
        assert(pageSize > intersectionCount),
        _loadPage = loadPage,
        _cacheDuration = cacheDuration,
        _logger = logger ?? ResourceConfig.instance.logger,
        _storage = storage,
        _pageableDataFactory =
            pageableDataFactory ?? OffsetPageableDataFactory<V>();

  /// Creates pageable resource with default in-memory storage.
  OffsetPageableResource.inMemory(
    String storageName, {
    required Future<List<V>> Function(K, int, int) loadPage,
    CacheDuration<K, OffsetPageableData<V>> cacheDuration =
        const CacheDuration.neverStale(),
    this.pageSize = defaultResourcePageSize,
    this.intersectionCount = defaultIntersectionCount,
    ResourceLogger? logger,
  })  : _loadPage = loadPage,
        _cacheDuration = cacheDuration,
        _logger = logger ?? ResourceConfig.instance.logger,
        _pageableDataFactory = OffsetPageableDataFactory<V>(),
        _storage = ResourceConfig.instance.inMemoryStorageFactory
            .createStorage<K, OffsetPageableData<V>>(
          storageName: storageName,
          logger: logger ?? ResourceConfig.instance.logger,
        );

  /// Creates pageable resource with default persistent storage.
  ///
  /// [decode] or [decodePageableData] should be provided for complex [V].
  /// Otherwise, the default JSON decoder will be used.
  OffsetPageableResource.persistent(
    String storageName, {
    required Future<List<V>> Function(K, int, int) loadPage,
    CacheDuration<K, OffsetPageableData<V>> cacheDuration =
        const CacheDuration.neverStale(),
    StorageDecoder<V>? decode,
    StorageDecoder<OffsetPageableData<V>>? decodePageableData,
    OffsetPageableDataFactory<V>? pageableDataFactory,
    this.pageSize = defaultResourcePageSize,
    this.intersectionCount = defaultIntersectionCount,
    ResourceLogger? logger,
  })  : _loadPage = loadPage,
        _cacheDuration = cacheDuration,
        _logger = logger ?? ResourceConfig.instance.logger,
        _pageableDataFactory =
            pageableDataFactory ?? OffsetPageableDataFactory<V>(),
        _storage = ResourceConfig.instance
            .requirePersistentStorageProvider()
            .createStorage<K, OffsetPageableData<V>>(
              storageName: storageName,
              decode: decodePageableData ??
                  _defaultJsonDecoder<V>(
                      decode, logger ?? ResourceConfig.instance.logger),
              logger: logger ?? ResourceConfig.instance.logger,
            );

  /// Page size that used to load data from external source.
  /// Passing as [limit] param in [LoadPageCallback].
  final int pageSize;

  /// Negative shift in offset value during page loading to allow
  /// intersection in results of two consecutive fetch requests.
  /// Intersection is needed to simple check if there is no new items
  /// on the server.
  final int intersectionCount;

  final ResourceStorage<K, OffsetPageableData<V>> _storage;

  /// Factory for [OffsetPageableData].
  /// Provide custom factory if you want to create custom [OffsetPageableData].
  final OffsetPageableDataFactory<V> _pageableDataFactory;

  final CacheDuration<K, OffsetPageableData<V>> _cacheDuration;
  final LoadPageCallback<K, V> _loadPage;
  final ResourceLogger? _logger;
  bool _loading = false;

  late final CachedResource<K, OffsetPageableData<V>> _cachedResource =
      CachedResource(
    storage: _storage,
    fetch: _loadFirstPage,
    cacheDuration: _cacheDuration,
  );

  /// Getter for he resource to access its methods.
  CachedResource<K, OffsetPageableData<V>> get resource => _cachedResource;

  /// Creates cold (defer) stream of the resource. On subscribe it triggers
  /// resource to load from cache or external source ([_loadPage] callback)
  /// if cache is stale.
  ///
  /// Set [forceReload] = true to force resource reloading from external source
  /// even if cache is not stale yet.
  ///
  /// Call [loadNextPage] to load new page. After new page loaded it emits
  /// new resource with all loaded items: old + new page.
  Stream<Resource<OffsetPageableData<V>>> asStream(K key,
          {bool forceReload = false}) =>
      _cachedResource.asStream(key, forceReload: forceReload);

  /// Makes cache stale.
  ///
  /// Also, if [reloadIfListened] (by default) then for each resource that
  /// currently is listened triggers reloading. If [emitLoadingOnReload]
  /// then emits loading state firstly.
  ///
  /// Returns future that completes after reloading finished with success
  /// or error.
  Future<void> invalidate(
    K key, {
    bool reloadIfListened = true,
    bool emitLoadingOnReload = true,
  }) =>
      _cachedResource.invalidate(
        key,
        reloadIfListened: reloadIfListened,
        emitLoadingOnReload: emitLoadingOnReload,
      );

  /// Closes all active subscriptions for the resource assigned to [key]
  /// and deletes its cached value from storage
  Future<void> remove(K key) => _cachedResource.remove(key);

  /// Closes all active subscriptions to resource of any key that was opened
  /// before and completely clears resource storage
  Future<void> clear() => _cachedResource.clearAll();

  /// Loads next page of pageable data and updates cache.
  ///
  /// Throws [InconsistentPageDataException] when detected that data
  /// was changed on the remote side, so we need to invalidate all data.
  Future<void> loadNextPage(K key) async {
    if (_loading) return;
    _loading = true;
    _logger?.trace(LoggerLevel.debug, 'PageableRes: Load next page requested');
    try {
      final currentData = (await _cachedResource.get(key)).data;

      // Get offset with shift to overlay [intersectionCount] items
      var loadedCount = currentData?.items.length ?? 0;
      final offset = max(0, loadedCount - intersectionCount);
      final expectedIntersection =
          offset == 0 ? loadedCount : intersectionCount;

      _logger?.trace(LoggerLevel.debug,
          'PageableRes: Load next page with offset=[$offset]');

      final nextPageItems = await _loadPage(key, offset, pageSize);

      return _cachedResource.updateCachedValue(key, (data) {
        final oldItems = data?.items ?? <V>[];
        _assertIntersectedItems(oldItems, nextPageItems, expectedIntersection);
        return _pageableDataFactory.create(
          loadedAll: nextPageItems.length < pageSize,
          items: oldItems + nextPageItems.sublist(expectedIntersection),
        );
      });
    } catch (error, trace) {
      _logger?.trace(LoggerLevel.error, 'PageableRes: Error loading next page',
          error, trace);
      rethrow;
    } finally {
      _loading = false;
    }
  }

  /// Detects if in next page data we receive [expectedIntersectionCount] items
  /// from old data, else throws [InconsistentPageDataException].
  ///
  /// Warning: we assumed that item can not change its relative position.
  /// Warning: In case of N new items inserted and the same amount (N)
  /// of old items deleted on previous pages, it can not be detected this way.
  void _assertIntersectedItems(
    List<V> oldItems,
    List<V> nextPage,
    int expectedIntersectionCount,
  ) {
    if (expectedIntersectionCount == 0) {
      // Nothing to check.
      return;
    }
    final expectedIntersection =
        oldItems.sublist(max(oldItems.length - expectedIntersectionCount, 0));
    final actualItems = nextPage.take(expectedIntersectionCount).toList();

    if (!DeepCollectionEquality().equals(actualItems, expectedIntersection)) {
      _logger?.trace(LoggerLevel.warning,
          'PageableRes: Data inconsistent: wrong intersection');
      throw const InconsistentPageDataException();
    }
  }

  Future<OffsetPageableData<V>> _loadFirstPage(K key) async {
    // Load first page
    final items = await _loadPage(key, 0, pageSize);
    // Try to detect if we can reuse cached data
    // to not reset cache to the first page.
    final cache =
        await _cachedResource.getCachedValue(key, synchronized: false);
    final firstCachedPage = cache?.items.take(items.length).toList();
    if (cache != null &&
        DeepCollectionEquality().equals(items, firstCachedPage)) {
      // First page of cached data is the same as newly requested.
      // Assume that there are no changes and we can keep cached data.
      return cache;
    }
    return _pageableDataFactory.create(
      loadedAll: items.length < pageSize,
      items: items,
    );
  }
}

StorageDecoder<OffsetPageableData<V>> _defaultJsonDecoder<V>(
    StorageDecoder<V>? decode,
    [ResourceLogger? logger]) {
  return (storedData) => OffsetPageableData.fromJson(
      storedData, decode ?? defaultStorageDecoder<V>(logger));
}

/// Factory to create [OffsetPageableData].
/// If you need to extend [OffsetPageableData] then provide a custom factory.
interface class OffsetPageableDataFactory<V> {
  /// Creates a factory of [OffsetPageableData].
  const OffsetPageableDataFactory();

  /// Creates [OffsetPageableData].
  OffsetPageableData<V> create(
          {required bool loadedAll, required List<V> items}) =>
      OffsetPageableData<V>(loadedAll: loadedAll, items: items);
}

/// Base class to represent pageable data.
interface class OffsetPageableData<V> {
  /// Creates simple class to represent pageable data.
  const OffsetPageableData({
    required this.loadedAll,
    required this.items,
  });

  /// Use this field to check if you need to call
  /// [OffsetPageableResource.loadNextPage]. If [loadedAll] = true then
  /// all items already loaded and request for next page will be ignored.
  final bool loadedAll;

  /// All items that was already loaded.
  final List<V> items;

  /// Converts [OffsetPageableData] to JSON.
  /// Used by storages that stores a value in JSON format.
  Map<String, dynamic> toJson() {
    return {
      'loadedAll': this.loadedAll,
      'items': this.items,
    };
  }

  /// Converts [OffsetPageableData] from JSON.
  /// Used by storages that stores a value in JSON format.
  static Future<OffsetPageableData<V>> fromJson<V>(
    Map<String, dynamic> map,
    StorageDecoder<V> decode,
  ) async {
    final itemsMap = map['items'] as List<dynamic>;
    final items = await Stream.fromIterable(itemsMap).asyncMap(decode).toList();
    return OffsetPageableData<V>(
      loadedAll: map['loadedAll'] as bool,
      items: items,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffsetPageableData &&
          runtimeType == other.runtimeType &&
          loadedAll == other.loadedAll &&
          DeepCollectionEquality().equals(items, other.items);

  @override
  int get hashCode => Object.hash(
        loadedAll,
        Object.hashAll(items),
      );
}

/// Exception that throws in case when inconsistent page data detected.
/// Usually it means that data on the server was changed and we need to reload
/// all items from the first page.
class InconsistentPageDataException implements Exception {
  /// Creates [InconsistentPageDataException].
  const InconsistentPageDataException();

  /// String representation to print in log
  @override
  String toString() => 'InconsistentPageDataException';
}
