## Cached Resource

[![pub package](https://img.shields.io/pub/v/cached_resource.svg)](https://pub.dev/packages/cached_resource)

Cached resource implementation based on `NetworkBoundResource` approach
to follow the single source of truth principle.

Define a single cached resource repository and subscribe for updates in multiple places,
trigger to refresh from any place and be sure that a single network request will be called 
and all listeners receive updated value.

## Usage

To use this plugin, add `cached_resource` as a dependency in your pubspec.yaml file.

### Configuration

In any place before usage of `CachedResource` call `ResourceConfig.setup` and provide
factories for persistent and/or secure storage.

Note: This step is required only to use `CachedResource.persistent` and `CachedResource.secure`.
But it is optional step to use in-memory storage `CachedResource.inMemory`.

```dart
void main() {
  // Configuration for cached_resource.
  ResourceConfig.setup(
    //inMemoryStorageFactory: const CustomMemoryResourceStorageProvider(),
    persistentStorageFactory: const HiveResourceStorageProvider(),
    secureStorageFactory: const FlutterSecureResourceStorageProvider(),
    logger: CustomLogger(),
  );

  runApp(const MyApp());
}
```

### Resource Storage

From the box there is only In-Memory storage shipped with the package.

Other storages should be added as new dependencies:

1. [resource_storage_hive](https://pub.dev/packages/resource_storage_hive) - simple persistent
   storage based on [hive](https://pub.dev/packages/hive) with simple JSON decoder.
2. [resource_storage_secure](https://pub.dev/packages/resource_storage_secure) - secure persistent
   storage based [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) with
   simple JSON decoder.

### Define a resource/repository

There are a few ways how to create a resource depending on used storage.

#### With In-Memory cache

```dart

class AccountBalanceRepository extends CachedResource<String, AccountBalance> {
  AccountBalanceRepository(AccountBalanceApi api)
      : super.inMemory(
          'account_balance',
          fetch: api.getAccountBalance,
          cacheDuration: const Duration(minutes: 15),
        );
}

//or

final accountBalanceResource = CachedResource<String, AccountBalance>.inMemory(
  'account_balance',
  fetch: api.getAccountBalance,
  decode: AccountBalance.fromJson,
  cacheDuration: const Duration(minutes: 15),
);

```

#### With persistent cache

The `persistentStorageFactory` should be already set by `ResourceConfig.setup`.

```dart

class CategoryRepository {
  CategoryRepository(CategoryApi api)
      : _categoryResource = CachedResource.persistent(
          'categories',
          fetch: (_) => api.getCategories(),
          cacheDuration: const Duration(days: 15),
          decode: Category.listFromJson,
          // Use executor only if [decode] callback does really heavy work,
          // for example if it parses a large json list with hundreds of heavy items
          executor: IsolatePoolExecutor().execute,
        );

  final CachedResource<String, List<Category>> _categoryResource;

  // Here we can use any constant key
  // as category list do not require any identifier.
  // But in some cases you may need a unique key,
  // for example if you need to separate lists by current authenticated user
  // then you can use currentUserId as a key.
  final _key = 'key';

  Stream<Resource<List<Category>>> watchCategories() =>
      _categoryResource.asStream(_key);

  Future<void> removeCategoryFromCache(String categoryId) {
    return _categoryResource.updateCachedValue(
        _key,
            (categories) =>
            categorys?.where((category) => category.id != categoryId).toList());
  }

  Future<void> invalidate() => _categoryResource.invalidate(_key);
}

```

#### With secure cache

The `secureStorageFactory` should be already set by `ResourceConfig.setup`.

```dart
class ProductSecretCodeRepository extends CachedResource<String, String> {
  ProductSecretCodeRepository(ProductApi api)
      : super.secure(
          'secret_code',
          fetch: api.getProductSecretCode,
          decode: (json) => json as String,
          cacheDuration: const Duration(days: 15),
        );
}
```

#### With custom resource storage

You can create custom resource storage by extending `ResourceStorage`
from [resource_storage](https://pub.dev/packages/resource_storage).

```dart
class UserRepository extends CachedResource<String, User> {
  UserRepository(UserApi api)
      : super(
          'users',
          fetch: api.getUserById,
          cacheDuration: const Duration(days: 15),
          storage: YourCustomStorage(),
        );
}
```

### Listen for the resource stream or just get value

To get a single value just call `cachedResource.get(key)`.
If cache is not stale then cached value will be returned,
else new fetch request will be called and received returned.

```dart
void foo() async {
  final resource = await resource.get(productId);
  if (resource.hasData) {
    final product = resource.data!;
    // do some work with product
  } else if (resource.isError) {
    final error = resource.error;
    final Product? productFromCache = resource.data;
    // show an error or use cached data
  }
}
```

To listen for resource just call `cachedResource.asStream(key)`.
It will emit `Resource` that can be one of 3 states:
 - `Resoorce.loading(data)` - fetch request triggered. `Resource.data` may contain old cached value.
 - `Resoorce.success(data)` - fetch request completed with fresh data or cache is not stale yet. `Resource.data` contains non null fresh value.
 - `Resoorce.error(data, error)` - fetch request completed with error. `Resource.data` may contain old cached value.

```dart
void startListening() async {
   _subscription = _categoryRepository.watchCategories().listen((resource) {
      if (resource.hasData) {
         final categories = resource.data!;
         // show categories
      } else if (resource.isError) {
         final error = resource.error!;
         final cachedCategories = resource.data;
         // handle error
      } else /*if (resource.isLoading)*/ { 
         // show loading state
      }
   });
}

// On need to reload categories from the server
void refresh() => _categoryRepository.invalidate();

void deleteCategory(String categoryId) async {
  await _api.deleteCategory(categoryId);
  // We don't want to reload full list from the server, so just delete item from the list in cache.
  // Each observer will receive updated list immediately.
  _categoryRepository.removeCategoryFromCache(categoryId);
}
```

## Contribution

Any contribution is welcome!
