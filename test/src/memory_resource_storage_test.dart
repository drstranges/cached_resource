import 'package:cached_resource/src/storage/memory_resource_storage.dart';
import 'package:resource_storage/resource_storage.dart';
import 'package:test/test.dart';

void main() {
  test('Timestamp should be set on store', () async {
    final storage = MemoryResourceStorage<String, int>(storageName: 'test');
    storage.put('key1', 1);
    final cacheEntry = await storage.getOrNull('key1');
    expect(cacheEntry?.value, 1);
    expect(cacheEntry?.storeTime, isNotNull);
  });

  test('Timestamp should be set using timestamp provider', () async {
    final timestamp = 123;
    final storage = MemoryResourceStorage<String, int>(
      storageName: 'test',
      timestampProvider: TimestampProvider.from(() => timestamp),
    );
    storage.put('key1', 1);
    final cacheEntry = await storage.getOrNull('key1');
    expect(cacheEntry?.value, 1);
    expect(cacheEntry?.storeTime, timestamp);
  });

  test('getOrNull method should return value if it was put to storage',
      () async {
    final storage = MemoryResourceStorage<String, int>(storageName: 'test');
    storage.put('key1', 1);
    storage.put('key2', 2);
    expect((await storage.getOrNull('key1'))?.value, 1);
    expect((await storage.getOrNull('key2'))?.value, 2);
    expect((await storage.getOrNull('key3')), null);
  });

  test('new value with existing key should override old one', () async {
    final storage = MemoryResourceStorage<String, int>(storageName: 'test');
    storage.put('key1', 1);
    storage.put('key1', 2);
    expect((await storage.getOrNull('key1'))?.value, 2);
  });

  test('remove method should remove key/value from storage', () async {
    final storage = MemoryResourceStorage<String, int>(storageName: 'test');
    storage.put('key1', 1);
    storage.put('key2', 2);
    storage.remove('key1');
    expect((await storage.getOrNull('key1'))?.value, null);
    expect((await storage.getOrNull('key2'))?.value, 2);
  });

  test('clear method should clear all cached data', () async {
    final storage = MemoryResourceStorage<String, int>(storageName: 'test');
    storage.put('key1', 1);
    storage.put('key2', 2);
    storage.clear();
    expect((await storage.getOrNull('key1'))?.value, null);
    expect((await storage.getOrNull('key2'))?.value, null);
  });
}
