// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cached_resource/cached_resource.dart';
import 'package:example/api/product_api.dart';

// Pageable repository
class StorePageableRepository
    extends OffsetPageableResource<String, ProductStore> {
  StorePageableRepository(ProductApi api)
      : super.persistent(
          'stores',
          loadPage: api.getProductStoresPageable,
          cacheDuration: const CacheDuration(minutes: 15),
          decode: ProductStore.fromJson,
          pageSize: 15,
        );
//or
// : super.inMemory(
//     'stores',
//     loadPage: api.getProductStoresPageable,
//     cacheDuration: const CacheDuration(minutes: 15),
//     pageSize: 15,
//   );
}
