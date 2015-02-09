//
//  PHAsset+DataSourceAdditions.m
//  On-the-Go
//
//  Created by Dimitar Ostoich on 2/3/15.
//
//

#import "PHAsset+DataSourceAdditions.h"

static PHFetchResult *collectionLists;

static PHFetchResult *allImageAssets;

@interface PHAsset () <PHPhotoLibraryChangeObserver>

@end

@implementation PHAsset (DataSourceAdditions)

+(void)load {
    //get all
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:(id<PHPhotoLibraryChangeObserver>)self];
    
    PHFetchOptions *options = [PHFetchOptions new];
    options.includeAllBurstAssets = YES;
    [options setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:NO]]];
    
    collectionLists = [PHCollectionList fetchCollectionListsWithType:PHCollectionListTypeMomentList subtype:PHCollectionListSubtypeMomentListCluster options:options];
 
    [options setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]]];
    allImageAssets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
}

+(void)fetchAssetsWithLocalIdentifiers:(NSArray *)assetIdentifiers includeBurstPhotos:(BOOL)includeBurstPhotos completion:(void(^)(PHFetchResult *result))result {
    if (!result) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        PHFetchOptions *fetchOptions = [PHFetchOptions new];
        fetchOptions.includeAllBurstAssets = includeBurstPhotos;
        fetchOptions.includeHiddenAssets = YES;
        PHFetchResult *res = [PHAsset fetchAssetsWithLocalIdentifiers:assetIdentifiers options:fetchOptions];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            result(res);
        });
    });
}

+ (void)photoLibraryDidChange:(PHChange *)changeInstance {
    
    PHFetchResultChangeDetails *details = [changeInstance changeDetailsForFetchResult:allImageAssets];
    for (PHAsset *asser in [details insertedObjects]) {
        //new asset in asset object
        PHFetchResult *result = [PHAssetCollection fetchAssetCollectionsContainingAsset:asser withType:PHAssetCollectionTypeMoment options:nil];
        NSLog(@"%@", result); // moment
        [result enumerateObjectsUsingBlock:^(PHCollection * obj, NSUInteger idx, BOOL *stop) {
            PHFetchResult *list = [PHCollectionList fetchCollectionListsContainingCollection:obj options:nil];
            NSLog(@"%@", list);
            
            [list enumerateObjectsUsingBlock:^(PHCollectionList *collectionList, NSUInteger idx, BOOL *stop) {
                if (collectionList.collectionListType != PHCollectionListTypeMomentList || collectionList.collectionListSubtype != PHCollectionListSubtypeMomentListCluster)
                    return;
                // grab new moment
            }];
            
            
        }];
    }
}

+(void)setFavorite:(BOOL)isFavorite forAsserIdentifier:(NSString *)identifier completion:(void(^)(BOOL success, NSError *error))completion {
    if (identifier.length == 0) {
        if (completion) {
            completion(NO, nil);
        }
        return;
    }
    [PHAsset fetchAssetsWithLocalIdentifiers:@[identifier] includeBurstPhotos:YES completion:^(PHFetchResult *result) {
        if (result.count == 0) {
            if (completion) {
                completion(NO, nil);
            }
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [result enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                PHAssetChangeRequest *request = [PHAssetChangeRequest changeRequestForAsset:obj];
                request.favorite = isFavorite;
            }];
        } completionHandler:^(BOOL success, NSError *error) {
            if (completion) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completion(success, error);
                }];
            }
        }];
        
    }];
}


@end
