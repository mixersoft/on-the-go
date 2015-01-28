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

// commands
extern NSString *kPhotoStreamChangeCommandValue; //updated {array}, removed {array}, added {array}

//extern NSString *kScheduleAssetsForUploadCommandValue; // assets {array}
//extern NSString *kUnscheduleAssetsForUploadCommandValue; // assets {array}

extern NSString *kScheduleDayRangeForUploadCommandValue; // fromDate {string}, toDate {string}
extern NSString *kUnscheduleDayRangeForUploadCommandValue;

extern NSString *kDidBeginAssetUploadCommandValue; // asset {phasset identifier}
extern NSString *kDidFinishAssetUploadCommandValue; // asset {phasset identifier}, name {string} (Parse name), success:bool
extern NSString *kDidUploadAssetProgressCommandValue; // asset {phasset identifier}:(string), totalBytesSent:(int64_t) totalBytesExpectedToSend:(int64_t)

extern NSString *kLastImageAssetIDCommandValue; // void

//Responds
extern NSString *kLastImageAssetIDResponseValue; // asset {phasset identifier}
extern NSString *kScheduleAssetsForUploadResponseValue; // assets {array}

@interface CordovaNativeMessenger : CDVPlugin

-(void)sendEvent:(NSDictionary*)eventData;

+(void)sendMessage:(NSDictionary*)data WithCommand:(NSString*)command;

+(void)addResponseBlock:(void(^)(NSString *command, id data))responceBlock;

@end
