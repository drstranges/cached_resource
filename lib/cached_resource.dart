// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library cached_resource;

/// Cached resource implementation based on `NetworkBoundResource`
/// to follow the single source of truth principle.
export 'package:resource_storage/resource_storage.dart';

export 'src/cached_resource.dart';
export 'src/resource.dart';
export 'src/resource_config.dart';
export 'src/storage/memory_resource_storage.dart';
export 'src/util/cache_duration.dart';
export 'src/util/pageable/offset_pageable_resource.dart';
