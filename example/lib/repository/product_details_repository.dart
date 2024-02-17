// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cached_resource/cached_resource.dart';
import 'package:example/api/product_api.dart';

// Here is a second way how you can use a cached resource.
// See [ProductRepository] for another approach.
class ProductDetailsRepository extends CachedResource<String, ProductDetails> {
  ProductDetailsRepository(ProductApi api)
      : super.inMemory(
          'product_details',
          fetch: api.getProductDetails,
          cacheDuration: const Duration(minutes: 15),
        );
}
