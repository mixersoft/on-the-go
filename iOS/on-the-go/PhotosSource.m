//
//  PhotosSource.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 12/13/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "PhotosSource.h"
#import "PhotosUploader.h"

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
            
            NSMutableArray *last = [assets lastObject];
            if (last) {
                PHFetchResult *lastResult = [last firstObject];
                NSDate *date = [[lastResult firstObject] creationDate];
                NSDateComponents *cLast = [NSCalendar.currentCalendar components:NSCalendarUnitEra|NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];
                NSDateComponents *cCurrent = [NSCalendar.currentCalendar components:NSCalendarUnitEra|NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:[[result firstObject]  creationDate]];
                if (cLast.year==cCurrent.year && cLast.month==cCurrent.month && cLast.day==cCurrent.day) {
                    [last addObject:result];
                }
                else {
                    [assets addObject:[NSMutableArray arrayWithObject:result]];
                }
            }
            else {
                [assets addObject:[NSMutableArray arrayWithObject:result]];
            }
        }];
        if (assets.count) {
            [_moments addObject:assets];
            [_collectionLists addObject:collection];
        }
    }
    
    PHFetchResult *result = [[[_moments firstObject] firstObject] firstObject];
    PhotosUploader *up = [PhotosUploader uploaderWithSessionConfigurationIdentifier:@"testIdentifier"];
    NSMutableArray *arr = [NSMutableArray new];
    [result enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [arr addObject:[obj localIdentifier]];
    }];
    [up scheduleAssetsWithIdentifiers:arr];
}

-(NSArray *)assetsForIndexPath:(NSIndexPath *)path {
    return _moments[path.section][path.row];
}

-(PHCollectionList *)collectionListAtIndex:(NSUInteger)index {
    return _collectionLists[index];
}

@end
