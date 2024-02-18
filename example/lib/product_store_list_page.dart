// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer';

import 'package:cached_resource/cached_resource.dart';
import 'package:example/repository/store_pageable_repository.dart';
import 'package:example/widgets/progress_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'api/product_api.dart';
import 'di.dart';
import 'widgets/error_state_widget.dart';

class ProductStoreListCubit extends Cubit<_State> {
  ProductStoreListCubit(this._repository)
      : super(const _State(isLoading: true));

  final StorePageableRepository _repository;
  StreamSubscription? _sub;

  void init(String productId) {
    _sub = _repository.asStream(productId).listen((resource) {
      if (resource.hasData) {
        // there is data (newly fetched or from cache) regardless if we have error or not
        emit(_State(
          items: resource.data!.items,
          loadedAll: resource.data!.loadedAll,
          hasError: resource.isError,
        ));
      } else if (resource.isError) {
        emit(_State(hasError: resource.isError));
      } else {
        emit(const _State(isLoading: true));
      }
    });
  }

  Future<void> onLoadMore(String productId) async {
    try {
      await _repository.loadNextPage(productId);
    } on InconsistentPageDataException {
      // refresh first page
      await _repository.invalidate(productId);
    } catch (e) {
      log('Error on loading more', error: e);
    }
  }

  Future<void> refresh(String productId) => _repository.invalidate(productId);

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

class _State {
  const _State({
    this.hasError = false,
    this.isLoading = false,
    this.loadedAll = false,
    this.items = const [],
  });

  final bool hasError;
  final bool isLoading;
  final bool loadedAll;
  final List<ProductStore> items;
}

class ProductStoreListPage extends StatelessWidget {
  const ProductStoreListPage({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Where to Buy')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: BlocProvider<ProductStoreListCubit>(
          create: (_) => ProductStoreListCubit(Di.storePageableRepository)
            ..init(productId),
          child: BlocConsumer<ProductStoreListCubit, _State>(
              listener: (context, state) {
            if (state.hasError && state.items.isNotEmpty) {
              // There is cached data but we received an error => show SnackBar.
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Demo error during network request!')));
            }
          }, builder: (context, state) {
            return switch (state) {
              _State(items: final items) when items.isNotEmpty => StoreList(
                  items,
                  productId: productId,
                  loadedAll: state.loadedAll,
                ),
              _State(hasError: true) => ErrorStateWidget(onRetry: () {
                  context.read<ProductStoreListCubit>().refresh(productId);
                }),
              _State(isLoading: true) => const ProgressStateWidget(),
              _ => const SizedBox.expand(
                  child: Center(child: Text('Empty')),
                ),
            };
          }),
        ),
      ),
    );
  }
}

class StoreList extends StatelessWidget {
  const StoreList(
    this._items, {
    required this.loadedAll,
    required this.productId,
    super.key,
  });

  final String productId;
  final bool loadedAll;
  final List<ProductStore> _items;

  @override
  Widget build(BuildContext context) {
    final itemCount = _items.length;
    return RefreshIndicator(
      onRefresh: () => context.read<ProductStoreListCubit>().refresh(productId),
      child: ListView.builder(
        itemBuilder: (context, index) {
          if (!loadedAll && index == itemCount) {
            context
                .read<ProductStoreListCubit>()
                .onLoadMore(productId);
            // Load more indicator in the end of the list
            return Container(
                padding: const EdgeInsets.all(8.0),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
            );
          }

          return ListTile(title: Text(_items[index].name));
        },
        itemCount: loadedAll ? itemCount : itemCount + 1,
      ),
    );
  }
}
