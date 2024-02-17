// Copyright 2024 The Cached Resource Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';

/// Resource representation that can have a few states:
/// - [ResourceState.loading] with optional [data] from cache
/// - [ResourceState.error] with optional [data] from cache
/// - [ResourceState.success] with [data] from cache if it still valid
/// or newly fetched
class Resource<T> {
  Resource._(
    this.state, {
    this.data,
    this.errorMessage,
    this.error,
    this.stackTrace,
  });

  /// Creates resource in [ResourceState.loading] state
  /// with optional [data] from cache
  Resource.loading([T? data]) : this._(ResourceState.loading, data: data);

  /// Creates resource in [ResourceState.success] state with [data]
  Resource.success(T? data) : this._(ResourceState.success, data: data);

  /// Creates resource in [ResourceState.error] state
  /// with optional [data] from cache, [errorMessage] to help debugging,
  /// [error] and [stackTrace]
  factory Resource.error(
    String errorMessage, {
    Object? error,
    StackTrace? stackTrace,
    T? data,
  }) =>
      Resource._(
        ResourceState.error,
        data: data,
        errorMessage: errorMessage,
        error: error,
        stackTrace: stackTrace,
      );

  final ResourceState state;
  final T? data;

  /// Error message to help debugging
  final String? errorMessage;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isLoading => state == ResourceState.loading;

  bool get isNotLoading => state != ResourceState.loading;

  bool get isError => state == ResourceState.error;

  bool get isNotError => state != ResourceState.error;

  bool get isSuccess => state == ResourceState.success;

  bool get hasData => data != null;

  /// Returns the encapsulated result of the given transform function
  /// applied to the encapsulated data and preserving all other fields
  Resource<R> map<R>(R? Function(T?) transform) => Resource._(
        state,
        data: transform(data),
        errorMessage: errorMessage,
        error: error,
        stackTrace: stackTrace,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Resource &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          errorMessage == other.errorMessage &&
          error == other.error &&
          stackTrace == other.stackTrace &&
          DeepCollectionEquality().equals(data, other.data);

  @override
  int get hashCode =>
      state.hashCode ^
      data.hashCode ^
      errorMessage.hashCode ^
      error.hashCode ^
      stackTrace.hashCode;

  @override
  String toString() {
    return 'Resource.${state.name}(msg: $errorMessage, hasData : $hasData)';
  }
}

enum ResourceState {
  loading,
  success,
  error,
}
