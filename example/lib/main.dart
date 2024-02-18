// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cached_resource/cached_resource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:resource_storage_hive/resource_storage_hive.dart';
import 'package:resource_storage_secure/resource_storage_secure.dart';

import 'api/product_api.dart';
import 'di.dart';
import 'product_details_page.dart';
import 'repository/product_repository.dart';
import 'repository/visibility_repository.dart';
import 'widgets/error_state_widget.dart';
import 'widgets/progress_state_widget.dart';

void main() {
  // Configuration for cached_resource.
  // Here you can provide storage implementation for In-Memory,
  // persistent and secure storages. Also you can set a custom logger.
  ResourceConfig.setup(
    persistentStorageFactory: const HiveResourceStorageProvider(),
    secureStorageFactory: const FlutterSecureResourceStorageProvider(),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cached Resource Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ProductListPage(),
    );
  }
}

class ProductListCubit extends Cubit<ProductListState> {
  ProductListCubit(this._repository)
      : super(const ProductListState(isLoading: true));

  final ProductRepository _repository;
  StreamSubscription? _sub;

  void init() {
    _sub = _repository.watchProducts().listen((resource) {
      if (resource.hasData) {
        // there is data (newly fetched or from cache) regardless if we have error or not
        emit(ProductListState(
          products: resource.data!,
          hasError: resource.isError,
        ));
      } else if (resource.isError) {
        emit(ProductListState(hasError: resource.isError));
      } else {
        emit(const ProductListState(isLoading: true));
      }
    });
  }

  void refresh() => _repository.invalidate();

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

class ProductListState {
  const ProductListState({
    this.hasError = false,
    this.isLoading = false,
    this.products = const [],
  });

  final bool hasError;
  final bool isLoading;
  final List<Product> products;
}

class ProductListPage extends StatelessWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: const [VisibilityActionButton()],
      ),
      body: const Padding(padding: EdgeInsets.all(20.0), child: _BodyContent()),
    );
  }
}

class _BodyContent extends StatelessWidget {
  const _BodyContent();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProductListCubit>(
      create: (_) => ProductListCubit(Di.productRepository)..init(),
      child: BlocConsumer<ProductListCubit, ProductListState>(
          listener: (context, state) {
        if (state.hasError && state.products.isNotEmpty) {
          // There is cached data but we received an error => show SnackBar.
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Demo error during network request!')));
        }
      }, builder: (context, state) {
        return switch (state) {
          ProductListState(products: final products) when products.isNotEmpty =>
            ProductList(products),
          ProductListState(hasError: true) => ErrorStateWidget(
              onRetry: () => context.read<ProductListCubit>().refresh()),
          ProductListState(isLoading: true) => const ProgressStateWidget(),
          _ => const SizedBox.expand(
              child: Center(child: Text('Empty')),
            ),
        };
      }),
    );
  }
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
      trailing: StreamBuilder<bool>(
        stream: Di.visibilityRepository.watchVisibility(VisibilityGroup.price),
        initialData: true,
        builder: (context, snapshot) =>
            Text(snapshot.data == true ? _product.price : '***'),
      ),
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

class VisibilityActionButton extends StatelessWidget {
  const VisibilityActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () =>
          Di.visibilityRepository.toggleVisibility(VisibilityGroup.price),
      icon: StreamBuilder<bool>(
        initialData: true,
        stream: Di.visibilityRepository.watchVisibility(VisibilityGroup.price),
        builder: (context, snapshot) {
          return Icon(
            snapshot.data == true ? Icons.visibility : Icons.visibility_off,
          );
        },
      ),
    );
  }
}
