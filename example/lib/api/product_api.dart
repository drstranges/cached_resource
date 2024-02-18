// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';

/// Fake Api implementation.
class ProductApi {
  int _counter = 1;

  Future<List<Product>> getProducts() =>
      Future.delayed(const Duration(seconds: 1), () {
        if (_counter++ % 5 == 1) {
          // simulate error during fetch
          throw Exception('Fake API exception to demonstrate error handling');
        }
        // simulate price update
        _priceFactor += 1;
        final result = _products.indexed
            .map((pair) => pair.$2.copyWith(price: _priceByIndex(pair.$1)))
            .toList();
        return result;
      });

  Future<ProductDetails> getProductDetails(String id) =>
      Future.delayed(const Duration(seconds: 1), () {
        final (index, productDetails) = _productDetails.indexed
            .firstWhere((pair) => pair.$2.baseInfo.id == id);
        // simulate price update
        final result = productDetails.copyWith(
            baseInfo:
                productDetails.baseInfo.copyWith(price: _priceByIndex(index)));
        return result;
      });

  Future<void> deleteProduct(String productId) =>
      Future.delayed(const Duration(seconds: 1), () async {
        _products.removeWhere((product) => product.id == productId);
        _productDetails
            .removeWhere((product) => product.baseInfo.id == productId);
      });

  Future<String> getProductSecretCode(String id) =>
      Future.delayed(const Duration(seconds: 1), () {
        final product = _products.firstWhere((product) => product.id == id);
        return product.id.hashCode.toRadixString(16);
      });

  Future<List<ProductStore>> getProductStoresPageable(
          String productId, int offset, int limit) =>
      Future.delayed(const Duration(seconds: 1), () {
        const totalCount = 200;
        final count = min(limit, totalCount - offset);
        final productTitle =
            _products.firstWhere((product) => product.id == productId).title;
        return List.generate(
          count,
          (index) =>
              ProductStore(name: '$productTitle Store #${offset + index + 1}'),
        );
      });
}

int _priceFactor = 1;

String _priceByIndex(int index) => '\$${index * 100 + _priceFactor}';

class Product {
  final String id;
  final String title;
  final String iconUrl;
  final String price;

  Product({
    required this.id,
    required this.title,
    required this.iconUrl,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'iconUrl': iconUrl,
      'price': price,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      title: json['title'] as String,
      iconUrl: json['iconUrl'] as String,
      price: json['price'] as String,
    );
  }

  static List<Product> listFromJson(dynamic json) {
    final list = json as List<dynamic>;
    return list.map((item) => Product.fromJson(item)).toList();
  }

  Product copyWith({
    String? id,
    String? title,
    String? iconUrl,
    String? price,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      iconUrl: iconUrl ?? this.iconUrl,
      price: price ?? this.price,
    );
  }
}

class ProductDetails {
  final Product baseInfo;
  final String extraDescription;

  ProductDetails({
    required this.baseInfo,
    required this.extraDescription,
  });

  Map<String, dynamic> toJson() {
    return {
      'baseInfo': baseInfo,
      'extraDescription': extraDescription,
    };
  }

  factory ProductDetails.fromJson(Map<String, dynamic> map) {
    return ProductDetails(
      baseInfo: map['baseInfo'] as Product,
      extraDescription: map['extraDescription'] as String,
    );
  }

  ProductDetails copyWith({
    Product? baseInfo,
    String? extraDescription,
  }) {
    return ProductDetails(
      baseInfo: baseInfo ?? this.baseInfo,
      extraDescription: extraDescription ?? this.extraDescription,
    );
  }
}

class ProductStore {
  final String name;

  ProductStore({required this.name});

  Map<String, dynamic> toJson() => {'name': name};

  factory ProductStore.fromJson(dynamic jsonMap) =>
      ProductStore(name: jsonMap['name'] as String);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductStore &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

final _products = <Product>[
  Product(
    id: '1',
    title: "Smartphone",
    iconUrl: 'phone_android',
    price: "\$499",
  ),
  Product(
    id: '2',
    title: "Laptop",
    iconUrl: 'laptop',
    price: "\$999",
  ),
  Product(
    id: '3',
    title: "Headphones",
    iconUrl: 'headphones',
    price: "\$149",
  ),
  Product(
    id: '4',
    title: "Smartwatch",
    iconUrl: 'watch',
    price: "\$299",
  ),
  Product(
    id: '5',
    title: "Tablet",
    iconUrl: 'tablet',
    price: "\$399",
  ),
  Product(
    id: '6',
    title: "Wireless Speaker",
    iconUrl: 'speaker',
    price: "\$129",
  ),
  Product(
    id: '7',
    title: "Gaming Console",
    iconUrl: 'videogame_asset',
    price: "\$399",
  ),
  Product(
    id: '8',
    title: "Camera",
    iconUrl: 'camera',
    price: "\$599",
  ),
  Product(
    id: '9',
    title: "Fitness Tracker",
    iconUrl: 'fitness_center',
    price: "\$99",
  ),
  Product(
    id: '10',
    title: "Bluetooth Earbuds",
    iconUrl: 'bluetooth',
    price: "\$79",
  ),
];

final _productDetails = [
  ProductDetails(
    baseInfo: _products[0],
    extraDescription:
        "The latest smartphone with advanced features and high-resolution display. Perfect for staying connected on the go.",
  ),
  ProductDetails(
    baseInfo: _products[1],
    extraDescription:
        "Powerful laptop with a sleek design, ideal for work or entertainment. Features include a fast processor and long battery life.",
  ),
  ProductDetails(
    baseInfo: _products[2],
    extraDescription:
        "Immerse yourself in your favorite music with these high-quality headphones. Comfortable to wear and with superior sound quality.",
  ),
  ProductDetails(
    baseInfo: _products[3],
    extraDescription:
        "Stay organized and track your fitness goals with this smartwatch. Receive notifications, monitor your health, and more.",
  ),
  ProductDetails(
    baseInfo: _products[4],
    extraDescription:
        "Portable tablet with a large touchscreen display. Great for watching movies, playing games, and productivity tasks on the go.",
  ),
  ProductDetails(
    baseInfo: _products[5],
    extraDescription:
        "Enjoy your favorite music wirelessly with this sleek and compact speaker. Features Bluetooth connectivity and long battery life.",
  ),
  ProductDetails(
    baseInfo: _products[6],
    extraDescription:
        "Experience the thrill of gaming with this powerful console. Play the latest games in stunning graphics and immerse yourself in virtual worlds.",
  ),
  ProductDetails(
    baseInfo: _products[7],
    extraDescription:
        "Capture life's precious moments with this high-quality camera. Features include a large sensor, fast autofocus, and 4K video recording.",
  ),
  ProductDetails(
    baseInfo: _products[8],
    extraDescription:
        "Stay motivated and track your fitness progress with this handy tracker. Monitor your steps, heart rate, and sleep patterns.",
  ),
  ProductDetails(
    baseInfo: _products[9],
    extraDescription:
        "Enjoy your music on the go with these lightweight and comfortable earbuds. Features Bluetooth connectivity and long-lasting battery.",
  ),
];

IconData downloadIcon(String url) => _icons[url]!;

final _icons = <String, IconData>{
  'phone_android': Icons.phone_android,
  'laptop': Icons.laptop,
  'headphones': Icons.headphones,
  'watch': Icons.watch,
  'tablet': Icons.tablet,
  'speaker': Icons.speaker,
  'videogame_asset': Icons.videogame_asset,
  'camera': Icons.camera,
  'fitness_center': Icons.fitness_center,
  'bluetooth': Icons.bluetooth,
};
