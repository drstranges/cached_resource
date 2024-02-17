// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../api/product_api.dart';
import '../repository/product_details_repository.dart';
import '../repository/product_repository.dart';
import '../repository/product_secret_code_repository.dart';

class DeleteProductUseCase {
  final ProductApi api;
  final ProductRepository productRepository;
  final ProductDetailsRepository productDetailsRepository;
  final ProductSecretCodeRepository secretCodeRepository;

  DeleteProductUseCase({
    required this.api,
    required this.productRepository,
    required this.productDetailsRepository,
    required this.secretCodeRepository,
  });

  Future<void> deleteProduct(String productId) async {
    // call the backend to delete the product
    await api.deleteProduct(productId);
    // remove product from cached list of products and notify listeners,
    // so we don't need to request a list from a server again.
    // Or we can call `productRepository.invalidate();` if we really
    // want to repeat fetching from a server.
    await productRepository.removeProductFromCache(productId);
    //clear cache for product details byt productId
    productDetailsRepository.remove(productId);
    productDetailsRepository.remove(productId);
    secretCodeRepository.remove(productId);
  }
}
