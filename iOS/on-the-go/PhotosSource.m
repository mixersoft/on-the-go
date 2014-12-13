//
//  PhotosSource.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 12/13/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "PhotosSource.h"

@implementation PhotosSource {
    NSMutableArray *_collectionLists;
    NSMutableArray *_moments;
}

+(instancetype)sharedInstance {
    static PhotosSource *_data = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _data = [[self alloc] init];
    });
    return _data;
}

-(void)invalidate {
    
    _collectionLists = nil;
    _moments = nil;
    [self reloadData];
    
}

-(NSUInteger)numberOfCollections {
    return [_moments count];
}

-(NSUInteger)numberOfMomentsInCollectionAtIndex:(NSUInteger)index {
    return [_moments[index] count];
}

-(void)reloadData {
    PHFetchOptions *options = [PHFetchOptions new];
    [options setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:NO]]];
    
    _collectionLists = [NSMutableArray new];
    _moments = [NSMutableArray new];

    PHFetchResult *collections = [PHCollectionList fetchMomentListsWithSubtype:PHCollectionListSubtypeMomentListCluster options:options];
    for (PHCollectionList * collection in collections) {
        
        PHFetchResult * momentsInCollection = [PHCollection fetchCollectionsInCollectionList:collection options:options];
        NSMutableArray *assets = [NSMutableArray new];
        [momentsInCollection enumerateObjectsUsingBlock:^(PHAssetCollection * momentsAssetCollection, NSUInteger idx, BOOL *stop) {
            PHFetchOptions *op = [PHFetchOptions new];
            [op setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]]];
            [op setPredicate:[NSPredicate predicateWithFormat:@"(mediaType = %d)", PHAssetMediaTypeImage]];
            PHFetchResult *result = [PHAsset fetchAssetsInAssetCollection:momentsAssetCollection options:op];
            
            if (!result.count) {
                return;
            }
            [assets addObject:result];
        }];
        if (assets.count) {
            [_moments addObject:assets];
            [_collectionLists addObject:collection];
        }
    }
}

-(PHFetchResult *)assetsForIndexPath:(NSIndexPath *)path {
    return _moments[path.section][path.row];
}

-(PHCollectionList *)collectionListAtIndex:(NSUInteger)index {
    return _collectionLists[index];
}

@end
