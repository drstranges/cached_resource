// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'offset_pageable_resource.dart';

class _MemoryOffsetPageableResource<K, V>
    extends OffsetPageableResource<K, V> {
  _MemoryOffsetPageableResource(
    super.storageName, {
    required super.loadPage,
    super.cacheDuration = const CacheDuration.neverStale(),
    super.pageSize = defaultResourcePageSize,
    super.intersectionCount = defaultIntersectionCount,
  });

  @override
  late final CachedResource<K, OffsetPageableData<V>> _cachedResource =
      CachedResource.inMemory(
    storageName,
    fetch: _loadFirstPage,
    cacheDuration: cacheDuration,
  );
}
