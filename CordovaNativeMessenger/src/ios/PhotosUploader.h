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
@optional
-(void)photoUploader:(PhotosUploader *)uploader didCancelUploadAssetIdentifier:(NSString *)assetIdentifier;
-(void)photoUploader:(PhotosUploader *)uploader didUploadAssetIdentifier:(NSString *)assetIdentifier responseData:(NSData *)data withError:(NSError *)error;
-(void)photoUploader:(PhotosUploader *)uploader didScheduleUploadForAssetWithIdentifier:(NSString *)assetIdentifier;
-(void)photoUploader:(PhotosUploader *)uploader didUploadDataForAssetWithIdentifier:(NSString *)asseetIdentifier totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;

-(void)photoUploaderFinishedProcessingBackgroundEvents:(PhotosUploader *)uploader;

@end

@interface PhotosUploader : NSObject

@property (nonatomic, assign) BOOL convertTo720p;

+(PhotosUploader *)uploaderWithSessionConfigurationIdentifier:(NSString *)identifier;
+(PhotosUploader *)sharedInstance;

-(void)scheduleAssetsWithIdentifiers:(NSArray *)localPHAssetIdentifiers;
-(void)unscheduleAssetsWithIdentifiers:(NSArray *)localPHAssetIdentifiers;

-(void)addDelegate:(id<PhotosUploaderDelegate>)delegate;
-(void)removeDelegate:(id<PhotosUploaderDelegate>)delegate;

-(void)currentlyScheduledAssetIDs:(void(^)(NSArray *))completion;

@end
