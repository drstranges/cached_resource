// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:resource_storage/resource_storage.dart';

typedef _CacheBox<K, V> = Map<K, CacheEntry<V>>;

/// Factory to provide instance of [MemoryResourceStorage].
class MemoryResourceStorageProvider implements ResourceStorageProvider {
  /// Creates factory of [MemoryResourceStorage].
  const MemoryResourceStorageProvider();

  @override
  ResourceStorage<K, V> createStorage<K, V>({
    required String storageName,
    StorageDecoder<V>? decode,
    StorageExecutor? executor,
    TimestampProvider? timestampProvider,
    ResourceLogger? logger,
  }) =>
      MemoryResourceStorage(
        storageName: storageName,
        timestampProvider: timestampProvider ?? const TimestampProvider(),
      );
}

/// Simple in-memory key-value resource storage
class MemoryResourceStorage<K, V> implements ResourceStorage<K, V> {
  /// Creates simple in-memory key-value resource storage.
  ///
  /// [storageName] is used only for [toString] to be visible in logs.
  ///
  /// Custom [timestampProvider] could be used in test to mock storeTime.
  MemoryResourceStorage({
    required this.storageName,
    this.timestampProvider = const TimestampProvider(),
  });

  /// Used only for [toString] to be visible in logs.
  final String storageName;

  /// Set custom timestamp provider if you need it in tests
  final TimestampProvider timestampProvider;

  /// In-memory cache
  final _cacheBox = _CacheBox<K, V>();

  @override
  Future<CacheEntry<V>?> getOrNull(K key) async => _cacheBox[key];

  @override
  Future<void> put(K key, V data, {int? storeTime}) async {
    _cacheBox[key] = CacheEntry(
      data,
      storeTime: storeTime ?? timestampProvider.getTimestamp(),
    );
  }

  @override
  Future<void> remove(K key) async => _cacheBox.remove(key);

  @override
  Future<void> clear() async => _cacheBox.clear();

  @override
  String toString() => 'MemoryResourceStorage<$K, $V>[$storageName]';
}
