// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cached_resource/cached_resource.dart';
import 'package:flutter/material.dart';
import 'package:resource_storage_hive/resource_storage_hive.dart';
import 'package:resource_storage_secure/resource_storage_secure.dart';

import 'product_list_page.dart';

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
