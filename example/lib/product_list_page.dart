// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:example/di.dart';
import 'package:flutter/material.dart';

import 'api/product_api.dart';
import 'product_details_page.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _repository = Di.productRepository;
  StreamSubscription? _sub;

  _State _state = _State(isLoading: true);

  @override
  void initState() {
    // Usually this logic places in Bloc/Cubit
    _sub = _repository.watchProducts().listen((resource) {
      if (resource.hasData) {
        setState(() {
          _state = _State(products: resource.data ?? []);
          if (resource.isError) {
            // if there is cached data but we received an error - show snackbar
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Demo error during network request!')));
          }
        });
      } else if (resource.isError) {
        setState(() {
          // There is no cached data to show but error received,
          // so we show full screen error
          _state = _State(hasError: true);
        });
      } else {
        //resource.isLoading
        setState(() {
          // There is no cached data but it's loading now,
          // so we show full screen progress bar
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: switch (_state) {
          _State(isLoading: false, hasError: false, products: final products) =>
            ProductList(products),
          _State(hasError: true) => SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Let\'s pretend there is a readable description of some error!',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Trigger resource to be reloaded
                      _repository.invalidate();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          _ => const SizedBox.expand(
              child: Center(child: CircularProgressIndicator()),
            ),
        },
      ),
    );
  }
}

class _State {
  final bool hasError;
  final bool isLoading;
  final List<Product> products;

  _State({
    this.hasError = false,
    this.isLoading = false,
    this.products = const [],
  });
}

class ProductList extends StatelessWidget {
  const ProductList(this._products, {super.key});

  final List<Product> _products;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => Di.productRepository.invalidate(),
      child: ListView.builder(
        itemBuilder: (context, index) => _ProductItem(_products[index]),
        itemCount: _products.length,
      ),
    );
  }
}

class _ProductItem extends StatelessWidget {
  _ProductItem(this._product) : super(key: Key(_product.id));

  final Product _product;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(downloadIcon(_product.iconUrl), size: 40),
      title: Text(_product.title),
      trailing: Text(_product.price),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsPage(productId: _product.id),
          ),
        );
      },
    );
  }
}
