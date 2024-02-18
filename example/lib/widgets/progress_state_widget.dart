/*
 * Copyright 2024 The Cached Resource Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'package:flutter/material.dart';

class ProgressStateWidget extends StatelessWidget {
  const ProgressStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
