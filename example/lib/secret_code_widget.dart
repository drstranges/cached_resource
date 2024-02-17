/*
 * Copyright 2024 The Cached Resource Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'package:flutter/material.dart';

import 'di.dart';

class SecretCodeWidget extends StatefulWidget {
  const SecretCodeWidget({required this.productId, super.key});

  final String productId;

  @override
  State<SecretCodeWidget> createState() => _SecretCodeWidgetState();
}

class _SecretCodeWidgetState extends State<SecretCodeWidget> {
  final _repository = Di.secretCodeRepository;

  _State _state = _State();

  void _showCode() async {
    setState(() => _state = _State(isLoading: true));
    final resource = await _repository.get(
      widget.productId,
      allowLoadingState: true,
    );
    if (!context.mounted) return;
    if (resource.hasData) {
      setState(() => _state = _State(code: resource.data!));
    } else if (resource.isError) {
      setState(() => _state = _State(hasError: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.deepOrange)),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 45,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Secret code:'),
          const SizedBox(width: 16),
          switch (_state) {
            _State(code: final String code) => Text(code),
            _State(hasError: true) => const Text('error!'),
            _State(isLoading: true) => const SizedBox(
                height: 16,
                width: 16,
                child: Center(child: CircularProgressIndicator()),
              ),
            _ => IconButton(
                onPressed: _showCode,
                icon: const Icon(Icons.remove_red_eye_outlined),
              ),
          },
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SecretCodeWidget oldWidget) {
    if (oldWidget.productId != widget.productId) {
      setState(() => _state = _State());
    }
    super.didUpdateWidget(oldWidget);
  }
}

class _State {
  final bool hasError;
  final bool isLoading;
  final String? code;

  _State({
    this.hasError = false,
    this.isLoading = false,
    this.code,
  });
}
