//
//  PhotosUploader.h
//  on-the-go
//
//  Created by Dimitar Ostoich on 12/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import <Foundation/Foundation.h>
@import QuartzCore;
@class PhotosUploader;

@protocol PhotosUploaderDelegate <NSObject>

-(void)photoUploader:(PhotosUploader *)uploader didUploadAssetIdentifier:(NSString *)assetIdentifier responseData:(NSData *)data withError:(NSError *)error;
-(void)photoUploader:(PhotosUploader *)uploader didScheduleUploadForAssetWithIdentifier:(NSString *)assetIdentifier;

@end

@interface PhotosUploader : NSObject

@property (nonatomic, assign) BOOL convertTo720p;

+(PhotosUploader *)uploaderWithSessionConfigurationIdentifier:(NSString *)identifier;

-(void)scheduleAssetsWithIdentifiers:(NSArray *)localPHAssetIdentifiers;

-(void)addDelegate:(id<PhotosUploaderDelegate>)delegate;

@end
