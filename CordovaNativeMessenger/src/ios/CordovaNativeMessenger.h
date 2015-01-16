//
//  CordovaNativeMessenger.h
//  on-the-go
//
//  Created by Ivaylo Dankolov on 11/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import <Cordova/CDVPlugin.h>

extern NSString *kSendNativeMessageNotification;

extern NSString *kCommandKey;
extern NSString *kDataKey;

// ommands
extern NSString *kPhotoStreamChangeCommandValue;

extern NSString *kScheduleAssetsForUploadCommandValue;
extern NSString *kUnscheduleAssetsForUploadCommandValue;
extern NSString *kScheduleDayRangeForUploadCommandValue;
extern NSString *kUnscheduleDayRangeForUploadCommandValue;

extern NSString *kDidBeginAssetUploadCommandValue;
extern NSString *kDidFinishAssetUploadCommandValue;


@interface CordovaNativeMessenger : CDVPlugin

-(void)sendEvent:(NSDictionary*)eventData;


+(void)sendMessage:(NSDictionary*)data WithCommand:(NSString*)command;

+(void)addResponseBlock:(void(^)(NSString *command, id data))responceBlock;

@end
