## 1.1.7
* [PAGEABLE] Add cache-related methods to [SizePageableResource] and [OffsetPageableResource]

## 1.1.6
* Use reentrant lock to fix dead-lock in [clearAllCache]
* [PAGEABLE] Fix InconsistentPageDataException if try to load next page if all items already

## 1.1.5
* SizePageableResource: Fix loading next page

## 1.1.4
* SizePageableResource: Fix resolving the next page to load

## 1.1.3
* SizePageableResource: Breaking change: [PageableData] => [SizePageableData].
* Fixed issue with restoring meta in [PageableData].

## 1.1.2
* SizePageableResource: Add method [isLoadedAll] to check if all items are loaded and [canReuseCache] to check if cache can be reused after invalidate.

## 1.1.1
* Make [PageableData] public

## 1.1.0
* Add [SizePageableResource] for pageable resource loading by page and size
 
## 1.0.9
* Allow rxdart >=0.27.0 <0.29.0

## 1.0.8
* Add [Resource.combineWith] method
* Fix StateError('You cannot add items while items are being added from addStream') on invalidate request while resource is already invalidating

## 1.0.7
* Add [CacheDuration.of] resolver

## 1.0.6
* Improve cache invalidation

## 1.0.5
* Override == and hashCode for [OffsetPageableData]

## 1.0.4
* Add [OffsetPageableResource]

## 1.0.3
* Upgrade resource_storage version to 1.0.2

## 1.0.2
* Set lover Dart sdk requirements

## 1.0.1
* Improved performance of loading from cache.
* Simplified interface.

## 1.0.0
* Add initial implementation of cached_resource package