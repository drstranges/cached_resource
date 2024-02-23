/*
 * Copyright 2024 The Cached Resource Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'package:resource_storage/resource_storage.dart';

/// Delegate for [CacheDuration] to check if cache is stale
typedef CheckIsCacheStale<K, V> = bool Function(
    K key, CacheEntry<V> cache, TimestampProvider timestampProvider);

/// Dynamic [CacheDuration] resolver
typedef DurationResolver<K, V> = CacheDuration<K, V> Function(
    K key, CacheEntry<V> cache);

/// Helper class to check if cache is stale
abstract interface class CacheDuration<K, V> {
  /// Creates dynamic cache duration resolver
  const factory CacheDuration.resolve(CheckIsCacheStale<K, V> delegate) =
      _DelegatedCacheDuration;

  /// Creates dynamic cache duration resolver
  const factory CacheDuration.of(DurationResolver<K, V> delegate) =
      _KeyBasedCacheDuration;

  /// Creates Duration resolver that never stale cache
  const factory CacheDuration.neverStale() = _NeverStaleCacheDuration;

  /// Create Duration resolver based on fixed time duration
  const factory CacheDuration({
    int days,
    int hours,
    int minutes,
    int seconds,
  }) = _FixedCacheDuration;

  bool isCacheStale(
    K key,
    CacheEntry<V> cache,
    TimestampProvider timestampProvider,
  );
}

class _FixedCacheDuration<K, V> implements CacheDuration<K, V> {
  const _FixedCacheDuration({
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
  }) : _durationMillis = Duration.microsecondsPerSecond * seconds +
            Duration.microsecondsPerMinute * minutes +
            Duration.microsecondsPerHour * hours +
            Duration.microsecondsPerDay * days;

  final int _durationMillis;

  @override
  bool isCacheStale(
      K key, CacheEntry<V> cache, TimestampProvider timestampProvider) {
    final storeTime = cache.storeTime;
    if (storeTime <= 0) {
      // seems like cached time was reset, so cache is stale
      return true;
    }
    final now = timestampProvider.getTimestamp();
    return storeTime < now - _durationMillis;
  }
}

class _DelegatedCacheDuration<K, V> implements CacheDuration<K, V> {
  const _DelegatedCacheDuration(this._delegate);

  final CheckIsCacheStale<K, V> _delegate;

  @override
  bool isCacheStale(
          K key, CacheEntry<V> cache, TimestampProvider timestampProvider) =>
      _delegate(key, cache, timestampProvider);
}

class _NeverStaleCacheDuration<K, V> implements CacheDuration<K, V> {
  const _NeverStaleCacheDuration();

  @override
  bool isCacheStale(
          K key, CacheEntry<V> cache, TimestampProvider timestampProvider) =>
      false;
}

class _KeyBasedCacheDuration<K, V> implements CacheDuration<K, V> {
  const _KeyBasedCacheDuration(this._delegate);

  final DurationResolver<K, V> _delegate;

  @override
  bool isCacheStale(
      K key, CacheEntry<V> cache, TimestampProvider timestampProvider) {
    return _delegate(key, cache).isCacheStale(key, cache, timestampProvider);
  }
}
