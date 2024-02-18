// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:cached_resource/cached_resource.dart';
import 'package:collection/collection.dart';

part 'memory_offset_pageable_resource.dart';
part 'persistent_offset_pageable_resource.dart';

const defaultResourcePageSize = 15;
const defaultIntersectionCount = 1;

typedef LoadPageCallback<K, V> = Future<List<V>> Function(
    K key, int offset, int limit);

abstract class OffsetPageableResource<K, V> {
  OffsetPageableResource(
    this.storageName, {
    required this.loadPage,
    required this.cacheDuration,
    OffsetPageableDataFactory<V>? pageableDataFactory,
    this.pageSize = defaultResourcePageSize,
    this.intersectionCount = defaultIntersectionCount,
  })  : assert(pageSize > intersectionCount),
        assert(intersectionCount >= 0),
        pageableDataFactory = pageableDataFactory ??
            OffsetPageableDataFactory<V>();

  factory OffsetPageableResource.inMemory(
    String storageName, {
    required LoadPageCallback<K, V> loadPage,
    CacheDuration<K, OffsetPageableData<V>> cacheDuration,
    int pageSize,
    int intersectionCount,
  }) = _MemoryOffsetPageableResource;

  factory OffsetPageableResource.persistent(
    String storageName, {
    required LoadPageCallback<K, V> loadPage,
    CacheDuration<K, OffsetPageableData<V>> cacheDuration,
    StorageDecoder<V>? decode,
    OffsetPageableDataFactory<V>? pageableDataFactory,
    int pageSize,
    int intersectionCount,
  }) = _PersistentOffsetPageableResource;

  final int intersectionCount;
  final String storageName;
  final OffsetPageableDataFactory<V> pageableDataFactory;
  final CacheDuration<K, OffsetPageableData<V>> cacheDuration;
  final LoadPageCallback<K, V> loadPage;
  final int pageSize;
  final _logger = ResourceConfig.instance.logger;
  bool _loading = false;

  CachedResource<K, OffsetPageableData<V>> get _cachedResource;

  Stream<Resource<OffsetPageableData<V>>> asStream(K key,
          {bool forceReload = false}) =>
      _cachedResource.asStream(key, forceReload: forceReload);

  Future<void> invalidate(K key) => _cachedResource.invalidate(key);

  Future<void> remove(K key) => _cachedResource.remove(key);

  Future<void> clear() => _cachedResource.clearAll();

  Future<OffsetPageableData<V>> _loadFirstPage(K key) async {
    // Load first page
    final items = await loadPage(key, 0, pageSize);
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
    return pageableDataFactory.create(
      loadedAll: items.length < pageSize,
      items: items,
    );
  }

  /// Loads next page of pageable data and updates repository
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

      final nextPageItems = await loadPage(key, offset, pageSize);

      return _cachedResource.updateCachedValue(key, (data) {
        final oldItems = data?.items ?? <V>[];
        _assertIntersectedItems(oldItems, nextPageItems, expectedIntersection);
        return pageableDataFactory.create(
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
}

interface class OffsetPageableDataFactory<V> {
  const OffsetPageableDataFactory();

  OffsetPageableData<V> create(
          {required bool loadedAll, required List<V> items}) =>
      OffsetPageableData<V>(loadedAll: loadedAll, items: items);

  StorageDecoder<OffsetPageableData<V>> get decoder => (data) => data;
}

interface class OffsetPageableData<V> {
  OffsetPageableData({
    required this.loadedAll,
    required this.items,
  });

  final bool loadedAll;
  final List<V> items;

  Map<String, dynamic> toJson() {
    return {
      'loadedAll': this.loadedAll,
      'items': this.items,
    };
  }

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
}

class InconsistentPageDataException implements Exception {
  const InconsistentPageDataException();

  @override
  String toString() => 'InconsistentPageDataException';
}
