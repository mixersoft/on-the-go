//
//  PhotosSource.h
//  on-the-go
//
//  Created by Dimitar Ostoich on 12/13/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import <UIKit/UIKit.h>
@import Photos;

@interface PhotosSource : UIViewController

+(instancetype) sharedInstance;

-(void)invalidate;

-(NSUInteger)numberOfCollections;

-(PHCollectionList *)collectionListAtIndex:(NSUInteger)index;

-(NSUInteger)numberOfMomentsInCollectionAtIndex:(NSUInteger)index;

-(PHFetchResult *)assetsForIndexPath:(NSIndexPath *)path;

@end
