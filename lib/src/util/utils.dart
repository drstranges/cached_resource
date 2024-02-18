/*
 * Copyright 2024 The Cached Resource Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'package:resource_storage/resource_storage.dart';

/// Simple decoder that return received value without transformation
StorageDecoder<V> defaultStorageDecoder<V>([ResourceLogger? logger]) {
  return (value) {
    try {
      return value as V;
    } catch (error, trace) {
      logger?.trace(
          LoggerLevel.error,
          'CachedResource: Error while decoding value from storage representation.'
          ' Default decoder just cast value from storage to target class.'
          ' Provide custom decoder for other cases.',
          error,
          trace);
      rethrow;
    }
  };
}
