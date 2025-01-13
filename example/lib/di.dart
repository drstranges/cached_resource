// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'api/product_api.dart';
import 'repository/product_details_repository.dart';
import 'repository/product_repository.dart';
import 'repository/product_secret_code_repository.dart';
import 'repository/store_pageable_repository.dart';
import 'repository/visibility_repository.dart';
import 'service/delete_product_use_case.dart';

/// Simple di helper. In real projects usually GetIt or any other.
class Di {
  static final api = ProductApi();
  static final productRepository = ProductRepository(api);
  static final productDetailsRepository = ProductDetailsRepository(api);
  static final secretCodeRepository = ProductSecretCodeRepository(api);
  static final visibilityRepository = VisibilityRepository();
  static final storePageableRepository = StorePageableRepository(api);
  static final deleteProductUseCase = DeleteProductUseCase(
    api: api,
    productRepository: productRepository,
    productDetailsRepository: productDetailsRepository,
    secretCodeRepository: secretCodeRepository,
    storePageableRepository: storePageableRepository,
  );
}
