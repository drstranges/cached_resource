// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'offset_pageable_resource.dart';

class _PersistentOffsetPageableResource<K, V>
    extends OffsetPageableResource<K, V> {
  _PersistentOffsetPageableResource(super.storageName, {
    required super.loadPage,
    super.cacheDuration = const CacheDuration.neverStale(),
    StorageDecoder<V>? decode,
    OffsetPageableDataFactory<V>? pageableDataFactory,
    super.pageSize,
    super.intersectionCount,
  }) : super(
    pageableDataFactory: pageableDataFactory ??
        _DefaultJsonOffsetPageableDataFactory<V>(
          decode ??
              (throw ArgumentError.value(
                  null,
                  'decode',
                  'Either [decode] either [pageableDataFactory]'
                      ' must be provided!')),
        ),
  );

  @override
  late final CachedResource<K, OffsetPageableData<V>> _cachedResource =
  CachedResource.persistent(
    storageName,
    fetch: _loadFirstPage,
    decode: pageableDataFactory.decoder,
    cacheDuration: cacheDuration,
  );
}

class _DefaultJsonOffsetPageableDataFactory<V>
    extends OffsetPageableDataFactory<V> {
  _DefaultJsonOffsetPageableDataFactory(this.decode);

  final StorageDecoder<V> decode;

  @override
  StorageDecoder<OffsetPageableData<V>> get decoder =>
          (dynamic storedData) =>
          OffsetPageableData.fromJson(storedData, decode);
}
