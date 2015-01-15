//
//  PhotosUploadScheduler.h
//  on-the-go
//
//  Created by Dimitar Ostoich on 12/16/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import <Foundation/Foundation.h>
@class PHFetchResult;

@interface PhotosUploadScheduler : NSObject

-(void)schedulePhotos:(PHFetchResult *)result;
-(void)scheduleDateRanggeFrom:(NSDate *)fromDate toDate:(NSDate *)toDate;

-(void)addIdentifierToSend:(NSString *)localIdentifier;

@end
