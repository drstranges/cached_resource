// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cached_resource/cached_resource.dart';
import 'package:collection/collection.dart';

import 'pageable_data.dart';

/// Default page size for [SizePageableResource]
const defaultPageableResourcePageSize = 15;

/// Callback to load items from the external source (server api, etc.)
/// Page starts from 1.
typedef LoadPageableCallback<K, V, R> = Future<PageableResponse<V, R>> Function(
    K key, int page, int size);

/// Represents pageable data with items and optional meta information.
/// Meta information can be used to store additional data like total count, etc.
class PageableResponse<V, R> {
  PageableResponse(this.items, {this.meta});
  final List<V> items;
  final R? meta;
}

/// Cached resource that allows pageable loading by page and size.
class SizePageableResource<K, V, R> {
  /// Creates pageable resource with custom storage
  ///
  /// [loadPage] - callback to load items from the external source (server api, etc.). Page starts from 1.
  /// [pageSize] - page size that used to load data from external source.
  /// [duplicatesDetectionEnabled] - whether to check that new page has items from the previous page.
  /// [cacheDuration] - duration of cache validity.
  /// [pageableDataFactory] - factory for [SizePageableData].
  /// [logger] - logger to log internal events.
  /// [storage] - custom storage to store pageable data.
  ///
  /// Throws [InconsistentPageDataException] if [duplicatesDetectionEnabled]
  /// and detected that new page has items that already loaded on a previous page
  /// (it means that data on the server was changed and we need to reload all items).
  SizePageableResource({
    required ResourceStorage<K, PageableData<V>> storage,
    required LoadPageableCallback<K, V, R> loadPage,
    CacheDuration<K, PageableData<V>> cacheDuration =
        const CacheDuration.neverStale(),
    PageableDataFactory<V>? pageableDataFactory,
    this.pageSize = defaultPageableResourcePageSize,
    this.duplicatesDetectionEnabled = true,
    ResourceLogger? logger,
  })  : _loadPage = loadPage,
        _cacheDuration = cacheDuration,
        _logger = logger ?? ResourceConfig.instance.logger,
        _storage = storage,
        _pageableDataFactory = pageableDataFactory ?? PageableDataFactory<V>();

  /// Creates pageable resource with default in-memory storage.
  ///
  /// [storageName] - name of the storage (like a table name for DB, or a file name).
  /// [loadPage] - callback to load items from the external source (server api, etc.). Page starts from 1.
  /// [pageSize] - page size that used to load data from external source.
  /// [duplicatesDetectionEnabled] - whether to check that new page has items from the previous page.
  /// [cacheDuration] - duration of cache validity.
  /// [logger] - logger to log internal events.
  ///
  /// Throws [InconsistentPageDataException] if [duplicatesDetectionEnabled]
  /// and detected that new page has items that already loaded on a previous page
  /// (it means that data on the server was changed and we need to reload all items).
  SizePageableResource.inMemory(
    String storageName, {
    required LoadPageableCallback<K, V, R> loadPage,
    CacheDuration<K, PageableData<V>> cacheDuration =
        const CacheDuration.neverStale(),
    this.pageSize = defaultPageableResourcePageSize,
    this.duplicatesDetectionEnabled = true,
    ResourceLogger? logger,
  })  : _loadPage = loadPage,
        _cacheDuration = cacheDuration,
        _logger = logger ?? ResourceConfig.instance.logger,
        _pageableDataFactory = PageableDataFactory<V>(),
        _storage = ResourceConfig.instance.inMemoryStorageFactory
            .createStorage<K, PageableData<V>>(
          storageName: storageName,
          logger: logger ?? ResourceConfig.instance.logger,
        );

  /// Creates pageable resource with default persistent storage.
  ///
  /// [storageName] - name of the storage (like a table name for DB, or a file name).
  /// [loadPage] - callback to load items from the external source (server api, etc.). Page starts from 1.
  /// [pageSize] - page size that used to load data from external source.
  /// [duplicatesDetectionEnabled] - whether to check that new page has items from the previous page.
  /// [cacheDuration] - duration of cache validity.
  /// [decode] - decoder for [V]. If not provided, the default JSON decoder will be used.
  /// [pageableDataFactory] - factory for [SizePageableData]. If not provided, the default [SizePageableDataFactory] will be used.
  /// [decodePageableData] - decoder for [SizePageableData]. If not provided, the default JSON decoder will be used.
  /// [logger] - logger to log internal events.
  ///
  /// Throws [InconsistentPageDataException] if [duplicatesDetectionEnabled]
  /// and detected that new page has items that already loaded on a previous page
  /// (it means that data on the server was changed and we need to reload all items).
  ///
  /// Throws [ResourceStorageProviderNotFoundException] if no persistent storage provider
  /// was found in [ResourceConfig].
  ///
  /// [decode] or [decodePageableData] should be provided for complex [V].
  /// Otherwise, the default JSON decoder will be used.
  SizePageableResource.persistent(
    String storageName, {
    required LoadPageableCallback<K, V, R> loadPage,
    CacheDuration<K, PageableData<V>> cacheDuration =
        const CacheDuration.neverStale(),
    StorageDecoder<V>? decode,
    StorageDecoder<PageableData<V>>? decodePageableData,
    PageableDataFactory<V>? pageableDataFactory,
    this.pageSize = defaultPageableResourcePageSize,
    this.duplicatesDetectionEnabled = true,
    ResourceLogger? logger,
  })  : _loadPage = loadPage,
        _cacheDuration = cacheDuration,
        _logger = logger ?? ResourceConfig.instance.logger,
        _pageableDataFactory = pageableDataFactory ?? PageableDataFactory<V>(),
        _storage = ResourceConfig.instance
            .requirePersistentStorageProvider()
            .createStorage<K, PageableData<V>>(
              storageName: storageName,
              decode: decodePageableData ??
                  PageableData.defaultJsonStorageDecoder<V>(
                      decode, logger ?? ResourceConfig.instance.logger),
              logger: logger ?? ResourceConfig.instance.logger,
            );

  /// Page size that used to load data from external source.
  /// Passing as [limit] param in [LoadPageableCallback].
  final int pageSize;

  /// Whether to check that new page has items from the previous page.
  final bool duplicatesDetectionEnabled;

  final ResourceStorage<K, PageableData<V>> _storage;

  /// Factory for [SizePageableData].
  /// Provide custom factory if you want to create custom [SizePageableData].
  final PageableDataFactory<V> _pageableDataFactory;

  final CacheDuration<K, PageableData<V>> _cacheDuration;
  final LoadPageableCallback<K, V, R> _loadPage;
  final ResourceLogger? _logger;

  late final CachedResource<K, PageableData<V>> _cachedResource =
      CachedResource(
    storage: _storage,
    fetch: _loadFirstPage,
    cacheDuration: _cacheDuration,
  );

  /// Getter for he resource to access its methods.
  CachedResource<K, PageableData<V>> get resource => _cachedResource;

  bool _loading = false;

  /// Creates cold (defer) stream of the resource. On subscribe it triggers
  /// resource to load from cache or external source ([_loadPage] callback)
  /// if cache is stale.
  ///
  /// Set [forceReload] = true to force resource reloading from external source
  /// even if cache is not stale yet.
  ///
  /// Call [loadNextPage] to load new page. After new page loaded it emits
  /// new resource with all loaded items: old + new page.
  Stream<Resource<PageableData<V>>> asStream(K key,
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
  /// Throws [InconsistentPageDataException] if [duplicatesDetectionEnabled]
  /// and detected that new page has items that already loaded on a previous page
  /// (it means that data on the server was changed and we need to reload all items).
  Future<void> loadNextPage(K key) async {
    if (_loading) return;
    _loading = true;
    _logger?.trace(LoggerLevel.debug, 'PageableRes: Load next page requested');
    try {
      final currentData = (await _cachedResource.get(key)).data;

      // Resolve fully loaded page count. If no data loaded yet, then load first page.
      final currentPageCount = (currentData?.items.length ?? 0) ~/ pageSize;
      final nextPage = currentPageCount + 1;
      _logger?.trace(
          LoggerLevel.debug, 'PageableRes: Load next page [$nextPage]');

      final nextPageResponse = await _loadPage(key, nextPage, pageSize);
      final loadedItems = nextPageResponse.items;

      return _cachedResource.updateCachedValue(key, (data) {
        final oldItems = data?.items ?? <V>[];
        if (duplicatesDetectionEnabled) {
          _assertIntersectedItems(oldItems, loadedItems);
        }
        checkConsistency(data, nextPageResponse);
        return _pageableDataFactory.create(
          loadedAll: loadedItems.length < pageSize,
          items: oldItems + loadedItems,
          meta: buildMeta(data, nextPageResponse),
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

  void _assertIntersectedItems(
    List<V> oldItems,
    List<V> nextPage,
  ) {
    final intersectedItems = oldItems.toSet().intersection(nextPage.toSet());
    if (intersectedItems.isNotEmpty) {
      _logger?.trace(LoggerLevel.warning,
          'PageableRes: Data inconsistent: new page has items from the previous page');
      throw const InconsistentPageDataException();
    }
  }

  Future<PageableData<V>> _loadFirstPage(K key) async {
    // Load first page
    final firstPageResponse = await _loadPage(key, 1, pageSize);
    final items = firstPageResponse.items;
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
      meta: buildMeta(null, firstPageResponse),
    );
  }

  /// Override this method to build meta information for the next page if needed.
  String? buildMeta(
    PageableData<V>? data,
    PageableResponse<V, R> nextPageResponse,
  ) {
    return null;
  }

  /// Override this method to check consistency of the data.
  /// If data is inconsistent, throw [InconsistentPageDataException].
  void checkConsistency(
    PageableData<V>? data,
    PageableResponse<V, R> nextPageResponse,
  ) {
    // Do nothing by default.
  }
}
