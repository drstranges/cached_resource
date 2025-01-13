// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cached_resource/cached_resource.dart';
import 'package:example/api/product_api.dart';

// Pageable repository
class StorePageableRepository //extends OffsetPageableResource<String, ProductStore> {
// StorePageableRepository(ProductApi api)
//     : super.persistent(
//   'stores',
//   loadPage: api.getProductStoresPageable,
//   cacheDuration: const CacheDuration(minutes: 15),
//   decode: ProductStore.fromJson,
//   pageSize: 15,
// );
//or
    extends SizePageableResource<String, ProductStore, void> {
  StorePageableRepository(ProductApi api)
      : super.persistent(
          'stores',
          loadPage: (key, page, size) async {
            var response =
                await api.getProductStoresPageSizable(key, page, size);
            return PageableResponse<ProductStore, void>(response);
          },
          cacheDuration: const CacheDuration(minutes: 15),
          decode: ProductStore.fromJson,
          pageSize: 15,
          duplicatesDetectionEnabled: true,
        );
//or
// : super.inMemory(
//     'stores',
//     loadPage: api.getProductStoresPageable,
//or   loadPage: api.getProductStoresPageSizable,
//     cacheDuration: const CacheDuration(minutes: 15),
//     pageSize: 15,
//   );
}
