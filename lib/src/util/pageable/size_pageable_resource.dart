// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cached_resource/cached_resource.dart';

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
  /// [pageableDataFactory] - factory for [SizeSizePageableData].
  /// [logger] - logger to log internal events.
  /// [storage] - custom storage to store pageable data.
  ///
  /// Throws [InconsistentPageDataException] if [duplicatesDetectionEnabled]
  /// and detected that new page has items that already loaded on a previous page
  /// (it means that data on the server was changed and we need to reload all items).
  SizePageableResource({
    required ResourceStorage<K, SizePageableData<V>> storage,
    required LoadPageableCallback<K, V, R> loadPage,
    CacheDuration<K, SizePageableData<V>> cacheDuration =
        const CacheDuration.neverStale(),
    SizePageableDataFactory<V>? pageableDataFactory,
    this.pageSize = defaultPageableResourcePageSize,
    this.duplicatesDetectionEnabled = true,
    ResourceLogger? logger,
  })  : _loadPage = loadPage,
        _cacheDuration = cacheDuration,
        _logger = logger ?? ResourceConfig.instance.logger,
        _storage = storage,
        _pageableDataFactory =
            pageableDataFactory ?? SizePageableDataFactory<V>();

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
    CacheDuration<K, SizePageableData<V>> cacheDuration =
        const CacheDuration.neverStale(),
    this.pageSize = defaultPageableResourcePageSize,
    this.duplicatesDetectionEnabled = true,
    ResourceLogger? logger,
  })  : _loadPage = loadPage,
        _cacheDuration = cacheDuration,
        _logger = logger ?? ResourceConfig.instance.logger,
        _pageableDataFactory = SizePageableDataFactory<V>(),
        _storage = ResourceConfig.instance.inMemoryStorageFactory
            .createStorage<K, SizePageableData<V>>(
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
  /// [pageableDataFactory] - factory for [SizeSizePageableData]. If not provided, the default [SizeSizePageableDataFactory] will be used.
  /// [decodeSizePageableData] - decoder for [SizeSizePageableData]. If not provided, the default JSON decoder will be used.
  /// [logger] - logger to log internal events.
  ///
  /// Throws [InconsistentPageDataException] if [duplicatesDetectionEnabled]
  /// and detected that new page has items that already loaded on a previous page
  /// (it means that data on the server was changed and we need to reload all items).
  ///
  /// Throws [ResourceStorageProviderNotFoundException] if no persistent storage provider
  /// was found in [ResourceConfig].
  ///
  /// [decode] or [decodeSizePageableData] should be provided for complex [V].
  /// Otherwise, the default JSON decoder will be used.
  SizePageableResource.persistent(
    String storageName, {
    required LoadPageableCallback<K, V, R> loadPage,
    CacheDuration<K, SizePageableData<V>> cacheDuration =
        const CacheDuration.neverStale(),
    StorageDecoder<V>? decode,
    StorageDecoder<SizePageableData<V>>? decodeSizePageableData,
    SizePageableDataFactory<V>? pageableDataFactory,
    this.pageSize = defaultPageableResourcePageSize,
    this.duplicatesDetectionEnabled = true,
    ResourceLogger? logger,
  })  : _loadPage = loadPage,
        _cacheDuration = cacheDuration,
        _logger = logger ?? ResourceConfig.instance.logger,
        _pageableDataFactory =
            pageableDataFactory ?? SizePageableDataFactory<V>(),
        _storage = ResourceConfig.instance
            .requirePersistentStorageProvider()
            .createStorage<K, SizePageableData<V>>(
              storageName: storageName,
              decode: decodeSizePageableData ??
                  SizePageableData.defaultJsonStorageDecoder<V>(
                      decode, logger ?? ResourceConfig.instance.logger),
              logger: logger ?? ResourceConfig.instance.logger,
            );

  /// Page size that used to load data from external source.
  /// Passing as [limit] param in [LoadPageableCallback].
  final int pageSize;

  /// Whether to check that new page has items from the previous page.
  final bool duplicatesDetectionEnabled;

  final ResourceStorage<K, SizePageableData<V>> _storage;

  /// Factory for [SizeSizePageableData].
  /// Provide custom factory if you want to create custom [SizeSizePageableData].
  final SizePageableDataFactory<V> _pageableDataFactory;

  final CacheDuration<K, SizePageableData<V>> _cacheDuration;
  final LoadPageableCallback<K, V, R> _loadPage;
  final ResourceLogger? _logger;

  late final CachedResource<K, SizePageableData<V>> _cachedResource =
      CachedResource(
    storage: _storage,
    fetch: _loadFirstPage,
    cacheDuration: _cacheDuration,
  );

  /// Getter for he resource to access its methods.
  CachedResource<K, SizePageableData<V>> get resource => _cachedResource;

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
  Stream<Resource<SizePageableData<V>>> asStream(K key,
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

  /// Completely clears resource storage
  /// and if [closeSubscriptions] closes all active subscriptions for resource
  /// of any key that was opened before.
  Future<void> clearAll({bool closeSubscriptions = false}) =>
      _cachedResource.clearAll(closeSubscriptions: closeSubscriptions);

  /// Applies [edit] function to cached value and emit as new success value
  /// If [notifyOnNull] set as true then will emit success(null) in case
  /// if there was a cached value but edit function returned null
  Future<void> updateCachedValue(
    K key,
    SizePageableData<V>? Function(SizePageableData<V>? value) edit, {
    bool notifyOnNull = false,
  }) =>
      _cachedResource.updateCachedValue(key, edit, notifyOnNull: notifyOnNull);

  /// Returns cached value if exists
  /// Set [synchronized] to false if you need to call this function
  /// inside [FetchCallable] or [updateCachedValue]
  Future<SizePageableData<V>?> getCachedValue(
    K key, {
    bool synchronized = true,
  }) =>
      _cachedResource.getCachedValue(key, synchronized: synchronized);

  /// Puts new value to cache and emits Resource.success(value)
  Future<void> putValue(K key, SizePageableData<V> value) =>
      _cachedResource.putValue(key, value);

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
      final currentData = await _cachedResource.getCachedValue(key);
      if (currentData?.loadedAll == true) {
        _logger?.trace(
            LoggerLevel.debug, 'PageableRes: All items are already loaded');
        return;
      }
      final nextPage = currentData?.nextPage ?? 1;
      _logger?.trace(
          LoggerLevel.debug, 'PageableRes: Load next page [$nextPage]');

      final nextPageResponse = await _loadPage(key, nextPage, pageSize);
      final loadedItems = nextPageResponse.items;

      return _cachedResource.updateCachedValue(key, (data) {
        if (data != currentData) {
          _logger?.trace(LoggerLevel.warning,
              'PageableRes: Cached data was changed during loading next page => ignore next page data');
          return data;
        }
        final oldItems = data?.items ?? <V>[];
        if (duplicatesDetectionEnabled) {
          _assertIntersectedItems(oldItems, loadedItems);
        }
        checkConsistency(data, nextPageResponse);
        return _pageableDataFactory.create(
          nextPage:
              isLoadedAll(nextPageResponse, pageSize) ? null : nextPage + 1,
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

  Future<SizePageableData<V>> _loadFirstPage(K key) async {
    // Load first page
    final firstPageResponse = await _loadPage(key, 1, pageSize);
    final items = firstPageResponse.items;
    // Try to detect if we can reuse cached data
    // to not reset cache to the first page.
    final cache =
        await _cachedResource.getCachedValue(key, synchronized: false);
    if (cache != null && canReuseCache(cache, firstPageResponse)) {
      // First page of cached data is the same as newly requested.
      // Assume that there are no changes and we can keep cached data.
      return cache;
    }
    return _pageableDataFactory.create(
      nextPage: isLoadedAll(firstPageResponse, pageSize) ? null : 2,
      items: items,
      meta: buildMeta(null, firstPageResponse),
    );
  }

  /// Override this method to build meta information for the next page if needed.
  String? buildMeta(
    SizePageableData<V>? data,
    PageableResponse<V, R> nextPageResponse,
  ) {
    return null;
  }

  /// Override this method to check consistency of the data.
  /// If data is inconsistent, throw [InconsistentPageDataException].
  void checkConsistency(
    SizePageableData<V>? data,
    PageableResponse<V, R> nextPageResponse,
  ) {
    // Do nothing by default.
  }

  /// Override this method to check if cache can be reused after invalidate.
  /// If cache can be reused, return true.
  /// [cache] - current cached data.
  /// [firstPageResponse] - response of the first page after [invalidate].
  bool canReuseCache(
    SizePageableData<V> cache,
    PageableResponse<V, R> firstPageResponse,
  ) =>
      false;

  /// Override this method to check if all items are loaded.
  bool isLoadedAll(PageableResponse<V, R> response, int pageSize) =>
      response.items.length < pageSize;
}
