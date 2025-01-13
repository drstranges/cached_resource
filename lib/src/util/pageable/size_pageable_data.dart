import 'package:collection/collection.dart';
import 'package:resource_storage/resource_storage.dart';

import '../utils.dart';

/// Base class to represent pageable data.
interface class SizePageableData<V> {
  /// Creates simple class to represent pageable data.
  const SizePageableData({
    required this.nextPage,
    required this.items,
    this.meta,
  });

  /// The number of the next page to load.
  /// If [nextPage] = null then all items already loaded.
  final int? nextPage;

  /// Use this field to check if you need to call
  /// [SizePageableResource.loadNextPage]. If [loadedAll] = true then
  /// all items already loaded and request for next page will be ignored.
  bool get loadedAll => nextPage == null;

  /// All items that was already loaded.
  final List<V> items;

  /// Additional data that can be used by the client. For example, total count.
  final String? meta;

  /// Converts [SizePageableData] to JSON.
  /// Used by storages that stores a value in JSON format.
  Map<String, dynamic> toJson() {
    return {
      'nextPage': this.nextPage,
      'items': this.items,
      'meta': this.meta,
    };
  }

  /// Converts [SizePageableData] from JSON.
  /// Used by storages that stores a value in JSON format.
  static Future<SizePageableData<V>> fromJson<V>(
    Map<String, dynamic> map,
    StorageDecoder<V> decode,
  ) async {
    final itemsMap = map['items'] as List<dynamic>;
    final items = await Stream.fromIterable(itemsMap).asyncMap(decode).toList();
    return SizePageableData<V>(
      nextPage: map['nextPage'] as int?,
      items: items,
      meta: map['meta'] as String?,
    );
  }

  static StorageDecoder<SizePageableData<V>> defaultJsonStorageDecoder<V>(
      StorageDecoder<V>? decode,
      [ResourceLogger? logger]) {
    return (storedData) => SizePageableData.fromJson(
        storedData, decode ?? defaultStorageDecoder<V>(logger));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SizePageableData &&
          runtimeType == other.runtimeType &&
          nextPage == other.nextPage &&
          DeepCollectionEquality().equals(items, other.items);

  @override
  int get hashCode => Object.hash(
        nextPage,
        Object.hashAll(items),
      );
}

/// Factory to create [SizePageableData].
/// The default factory creates [SizePageableData] with [loadedAll] and [items] fields.
/// If you need to add more fields to [SizePageableData] then you need to provide a custom factory.
/// The custom factory should extend this class and override [create] method.
/// [V] - type of items in [SizePageableData].
interface class SizePageableDataFactory<V> {
  /// Creates a factory of [SizePageableData].
  const SizePageableDataFactory();

  /// Creates [SizePageableData].
  SizePageableData<V> create({
    required int? nextPage,
    required List<V> items,
    String? meta,
  }) =>
      SizePageableData<V>(nextPage: nextPage, items: items, meta: meta);
}
