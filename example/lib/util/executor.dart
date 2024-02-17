// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Fake executor that runs tasks in separate isolate.
/// Usually used any external library (worker_manager, etc.)
/// or own implementation with reusable pool of isolates.
class Executor {
  FutureOr<T> execute<T>(FutureOr<T> Function() task) async =>
      compute((_) => task(), null);
}