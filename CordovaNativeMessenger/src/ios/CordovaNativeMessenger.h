//
//  CordovaNativeMessenger.h
//  on-the-go
//
//  Created by Ivaylo Dankolov on 11/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import <Cordova/CDVPlugin.h>

extern NSString *kSendNativeMessageNotification;

@interface CordovaNativeMessenger : CDVPlugin

-(void)sendEvent:(NSDictionary*)eventData;

@end
