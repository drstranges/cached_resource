// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cached_resource/cached_resource.dart';

// Local persistent resource without [fetch] callback.
class VisibilityRepository {
  final _resource =
      CachedResource<VisibilityGroup, bool>.persistent('visibility');

  Stream<bool> watchVisibility(VisibilityGroup group) => _resource
      .asStream(group)
      .map((res) => res.data ?? group.defaultVisibility);

  Future<void> toggleVisibility(VisibilityGroup group) =>
      _resource.updateCachedValue(
        group,
        (visible) => !(visible ?? group.defaultVisibility),
      );
}

enum VisibilityGroup {
  price(true),
  accountBalance(true);

  const VisibilityGroup(this.defaultVisibility);

  final bool defaultVisibility;

  /// This field used by CachedResource to convert key to String.
  /// If `resourceKey` field is not provided for complex object,
  /// it fallbacks to use `toString` and prints warning in log.
  String get resourceKey => name;
}
