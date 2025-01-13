import 'package:collection/collection.dart';
import 'package:resource_storage/resource_storage.dart';

import '../utils.dart';

/// Base class to represent pageable data.
interface class PageableData<V> {
  /// Creates simple class to represent pageable data.
  const PageableData({
    required this.loadedAll,
    required this.items,
    this.meta,
  });

  /// Use this field to check if you need to call
  /// [SizePageableResource.loadNextPage]. If [loadedAll] = true then
  /// all items already loaded and request for next page will be ignored.
  final bool loadedAll;

  /// All items that was already loaded.
  final List<V> items;

  /// Additional data that can be used by the client. For example, total count.
  final String? meta;

  /// Converts [PageableData] to JSON.
  /// Used by storages that stores a value in JSON format.
  Map<String, dynamic> toJson() {
    return {
      'loadedAll': this.loadedAll,
      'items': this.items,
      'meta': this.meta,
    };
  }

  /// Converts [PageableData] from JSON.
  /// Used by storages that stores a value in JSON format.
  static Future<PageableData<V>> fromJson<V>(
    Map<String, dynamic> map,
    StorageDecoder<V> decode,
  ) async {
    final itemsMap = map['items'] as List<dynamic>;
    final items = await Stream.fromIterable(itemsMap).asyncMap(decode).toList();
    return PageableData<V>(
      loadedAll: map['loadedAll'] as bool,
      items: items,
    );
  }

  static StorageDecoder<PageableData<V>> defaultJsonStorageDecoder<V>(
      StorageDecoder<V>? decode,
      [ResourceLogger? logger]) {
    return (storedData) => PageableData.fromJson(
        storedData, decode ?? defaultStorageDecoder<V>(logger));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageableData &&
          runtimeType == other.runtimeType &&
          loadedAll == other.loadedAll &&
          DeepCollectionEquality().equals(items, other.items);

  @override
  int get hashCode => Object.hash(
        loadedAll,
        Object.hashAll(items),
      );
}

/// Factory to create [PageableData].
/// The default factory creates [PageableData] with [loadedAll] and [items] fields.
/// If you need to add more fields to [PageableData] then you need to provide a custom factory.
/// The custom factory should extend this class and override [create] method.
/// [V] - type of items in [PageableData].
interface class PageableDataFactory<V> {
  /// Creates a factory of [PageableData].
  const PageableDataFactory();

  /// Creates [PageableData].
  PageableData<V> create({
    required bool loadedAll,
    required List<V> items,
    String? meta,
  }) =>
      PageableData<V>(loadedAll: loadedAll, items: items, meta: meta);
}
