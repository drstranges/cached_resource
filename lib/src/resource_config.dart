// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cached_resource/cached_resource.dart';

/// Global config for CachedResource
class ResourceConfig {
  /// Call before first usage of CachedResource to change
  /// default storage factories.
  ///
  /// By default only In-Memory factory is set.
  /// Persistent and Secure storage factories required to be set before
  /// first usage.
  ///
  /// !: To be able to use persistent and secure storage you need to provide
  /// their factories here.
  ///
  /// Example:
  /// ```dart
  /// ResourceConfig.setup(
  ///    logger: MyCustomLogger(),
  ///    inMemoryStorageFactory: CustomMemoryResourceStorageProvider(),
  ///    persistentStorageFactory: HiveResourceStorageProvider(),
  ///    secureStorageFactory: SecureResourceStorageProvider(),
  ///  );
  /// ```
  static void setup({
    ResourceStorageProvider? persistentStorageFactory,
    ResourceStorageProvider? secureStorageFactory,
    ResourceStorageProvider inMemoryStorageFactory =
        const MemoryResourceStorageProvider(),
    ResourceLogger? logger = const ResourceLogger(),
  }) {
    instance = ResourceConfig._(
      logger: logger,
      inMemoryStorageFactory: inMemoryStorageFactory,
      persistentStorageFactory: persistentStorageFactory,
      secureStorageFactory: secureStorageFactory,
    );
  }

  ResourceConfig._({
    this.logger = const ResourceLogger(),
    this.inMemoryStorageFactory = const MemoryResourceStorageProvider(),
    this.persistentStorageFactory,
    this.secureStorageFactory,
  });

  /// Instance of current resource config.
  static ResourceConfig instance = ResourceConfig._();

  /// Default logger instance
  final ResourceLogger? logger;

  /// Storage factory that used to create in-memory storage
  /// when [CachedResource.inMemory] called.
  final ResourceStorageProvider inMemoryStorageFactory;

  /// Storage factory that used to create persistent storage
  /// when [CachedResource.persistent] called.
  final ResourceStorageProvider? persistentStorageFactory;

  /// Storage factory that used to create secure storage
  /// when [CachedResource.secure] called.
  final ResourceStorageProvider? secureStorageFactory;

  /// Returns persistent storage factory if provided, else throws [StateError]
  ResourceStorageProvider requirePersistentStorageProvider() {
    final factory = persistentStorageFactory;
    if (factory == null) {
      throw StateError('Factory for persistent storage not set.'
          ' Call [ResourceConfig.setup] before usage.');
    }
    return factory;
  }

  /// Returns secure storage factory if provided, else throws [StateError]
  ResourceStorageProvider requireSecureStorageProvider() {
    final factory = secureStorageFactory;
    if (factory == null) {
      throw StateError('Factory for secure storage not set.'
          ' Call [ResourceConfig.setup] before usage.');
    }
    return factory;
  }
}
