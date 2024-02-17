// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'api/product_api.dart';
import 'repository/product_details_repository.dart';
import 'repository/product_repository.dart';
import 'repository/product_secret_code_repository.dart';
import 'repository/visibility_repository.dart';
import 'service/delete_product_use_case.dart';

/// Simple di helper. In real projects usually GetIt or any other.
class Di {
  static final _api = ProductApi();
  static final productRepository = ProductRepository(_api);
  static final productDetailsRepository = ProductDetailsRepository(_api);
  static final secretCodeRepository = ProductSecretCodeRepository(_api);
  static final visibilityRepository = VisibilityRepository();
  static final deleteProductUseCase = DeleteProductUseCase(
    api: _api,
    productRepository: productRepository,
    productDetailsRepository: productDetailsRepository,
    secretCodeRepository: secretCodeRepository,
  );
}
