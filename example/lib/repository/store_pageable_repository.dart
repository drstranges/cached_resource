// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cached_resource/cached_resource.dart';
import 'package:example/api/product_api.dart';

// Pageable repository
class StorePageableRepository {
  StorePageableRepository(ProductApi api)
      : _resource = OffsetPageableResource<String, ProductStore>.persistent(
          'stores',
          loadPage: api.getProductStoresPageable,
          cacheDuration: const CacheDuration(minutes: 15),
          decode: ProductStore.fromJson,
          pageSize: 15,
        );
  //or
  // : _resource = OffsetPageableResource<String, ProductStore>.inMemory(
  //     'stores',
  //     loadPage: api.getProductStoresPageable,
  //     cacheDuration: const CacheDuration(minutes: 15),
  //     pageSize: 15,
  //   );

  final OffsetPageableResource<String, ProductStore> _resource;

  Stream<Resource<OffsetPageableData<ProductStore>>> asStream(String productId,
          {bool forceReload = false}) =>
      _resource.asStream(productId, forceReload: forceReload);

  Future<void> loadNextPage(String productId) =>
      _resource.loadNextPage(productId);

  Future<void> invalidate(String productId) => _resource.invalidate(productId);

  Future<void> remove(String productId) => _resource.remove(productId);

  Future<void> clear() => _resource.clear();
}
