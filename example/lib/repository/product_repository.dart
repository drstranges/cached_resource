// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cached_resource/cached_resource.dart';
import 'package:example/api/product_api.dart';
import 'package:example/util/executor.dart';

// Here is a first way how you can use a cached resource.
// See [ProductDetailsRepository] for another approach.
  class ProductRepository {
    ProductRepository(ProductApi api)
        : _productResource = CachedResource.persistent(
            'products',
            fetch: (_) => api.getProducts(),
            cacheDuration: const CacheDuration(minutes: 1),
            decode: Product.listFromJson,
            // Use executor only if [decode] callback does really heavy work,
            // for example if it parses a large json list with hundreds of heavy items
            executor: Executor().execute,
          );

    final CachedResource<String, List<Product>> _productResource;

    // Here we can use any constant key
    // as product list do not require any identifier.
    // But in some cases you may need a unique key,
    // for example if you need to separate storages for each users/profiles
    // then you can use currentUserId as a key.
    final _key = 'key';

    Stream<Resource<List<Product>>> watchProducts() =>
        _productResource.asStream(_key);

    Future<void> removeProductFromCache(String productId) {
      return _productResource.updateCachedValue(
          _key,
          (products) =>
              products?.where((product) => product.id != productId).toList());
    }

    Future<void> invalidate() => _productResource.invalidate(_key);
  }
