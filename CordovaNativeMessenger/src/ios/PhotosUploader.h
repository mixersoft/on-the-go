//
//  PhotosUploader.h
//  on-the-go
//
//  Created by Dimitar Ostoich on 12/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "NSURLSessionTaskInfo.h"

@class PhotosUploader;

@protocol PhotosUploaderDelegate <NSObject>
@optional

-(void)photoUploader:(PhotosUploader *)uploader didFinishUploadAssetIdentifier:(NSString *)assetIdentifier;
-(void)photoUploader:(PhotosUploader *)uploader didScheduleUploadForAssetWithIdentifier:(NSString *)assetIdentifier;
-(void)photoUploader:(PhotosUploader *)uploader didUploadDataForAssetWithIdentifier:(NSString *)asseetIdentifier totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;
-(void)photoUploader:(PhotosUploader *)uploader didFailToScheduleAssetIdentifier:(NSString *)assetIdentifier isMissing:(BOOL)isMissing error:(NSError *)error;

-(void)photoUploaderFinishedProcessingBackgroundEvents:(PhotosUploader *)uploader;

@end

@interface PhotosUploader : NSObject

@property (nonatomic, assign) BOOL allowsCellularAccess;


+(PhotosUploader *)uploaderWithSessionConfigurationIdentifier:(NSString *)identifier;
+(PhotosUploader *)sharedInstance;

-(void)scheduleAssetsWithIdentifiers:(NSArray *)localPHAssetIdentifiers options:(NSDictionary *)options;
-(void)unscheduleAssetsWithIdentifiers:(NSArray *)localPHAssetIdentifiers completion:(void(^)(NSString *identifier, BOOL wasCanceled))completion;

-(void)unscheduleAllAssetsWithCompletion:(void(^)(void))completion;

-(void)addDelegate:(id<PhotosUploaderDelegate>)delegate;
-(void)removeDelegate:(id<PhotosUploaderDelegate>)delegate;

-(void)currentlyScheduledAssetIDs:(void(^)(NSArray *))completion;

-(NSArray *)allSessionTaskInfos;

-(BOOL)removeSessionTaskInfoWithIdentifier:(NSString*)identifier;

-(NSURLSessionTaskInfo *)sessionTaskInfoForIdentifier:(NSString *)identifier;

@end
