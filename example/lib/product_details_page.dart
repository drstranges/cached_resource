// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:example/di.dart';
import 'package:example/secret_code_widget.dart';
import 'package:example/widgets/error_state_widget.dart';
import 'package:flutter/material.dart';

import 'api/product_api.dart';
import 'product_store_list_page.dart';
import 'widgets/progress_state_widget.dart';

// Usually any logic placed in Bloc/Cubit and stateless widget used
class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final _repository = Di.productDetailsRepository;
  StreamSubscription? _sub;

  _State _state = _State(isLoading: true);

  @override
  void initState() {
    // Listen for product details update.
    _sub = _repository
        .asStream(widget.productId, forceReload: true)
        .listen((resource) {
      if (resource.hasData) {
        setState(() {
          _state = _State(product: resource.data!);
          if (resource.isError) {
            // if there is cached data but we received an error - show snackbar
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Demo error during network request!')));
          }
        });
      } else if (resource.isError) {
        setState(() {
          // Set error state
          _state = _State(hasError: true);
        });
      } else if (resource.isLoading) {
        setState(() {
          // Set loading state
          _state = _State(isLoading: true);
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _deleteProduct(String productId) async {
    _sub?.cancel();
    setState(() => _state = _State(isLoading: true));
    // Trigger use case to delete the product
    await Di.deleteProductUseCase.deleteProduct(productId);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: switch (_state) {
          _State(
            isLoading: false,
            hasError: false,
            product: final ProductDetails product
          ) =>
            ProductDetailsWidget(
              product,
              onDeletePressed: () => _deleteProduct(product.baseInfo.id),
            ),
          _State(hasError: true) => ErrorStateWidget(onRetry: () {
              // Trigger resource to be reloaded
              _repository.invalidate(widget.productId);
            }),
          _ => const ProgressStateWidget(),
        },
      ),
    );
  }
}

class _State {
  final bool hasError;
  final bool isLoading;
  final ProductDetails? product;

  _State({
    this.hasError = false,
    this.isLoading = false,
    this.product,
  });
}

class ProductDetailsWidget extends StatelessWidget {
  const ProductDetailsWidget(
    this._product, {
    required this.onDeletePressed,
    super.key,
  });

  final ProductDetails _product;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 60,
          child: Icon(downloadIcon(_product.baseInfo.iconUrl), size: 40),
        ),
        const SizedBox(height: 16),
        Text(_product.baseInfo.price,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Text(_product.baseInfo.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        SecretCodeWidget(productId: _product.baseInfo.id),
        const SizedBox(height: 16),
        Text(_product.extraDescription, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProductStoreListPage(productId: _product.baseInfo.id),
                ),
              );
            },
            child: const Text('Where to buy')),
        const Spacer(),
        ElevatedButton(
          onPressed: onDeletePressed,
          child: Text(
            'Delete product',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.apply(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}
