// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cached_resource/cached_resource.dart';
import 'package:example/api/product_api.dart';

class ProductSecretCodeRepository extends CachedResource<String, String> {
  ProductSecretCodeRepository(ProductApi api)
      : super.secure(
          'secret_code',
          fetch: api.getProductSecretCode,
          decode: (json) => json as String,
          cacheDuration: const Duration(days: 15),
        );
}
