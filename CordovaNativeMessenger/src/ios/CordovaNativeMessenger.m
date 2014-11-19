//
//  CordovaNativeMessenger.m
//  on-the-go
//
//  Created by Ivaylo Dankolov on 11/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "CordovaNativeMessenger.h"

NSString *kSendNativeMessageNotification = @"com.mixersoft.on-the-go.SendNativeMessageNotification";

@interface CordovaNativeMessenger () {
    NSString *callbackId;
}

@end

@implementation CordovaNativeMessenger

-(void)bindListener:(CDVInvokedUrlCommand*) command {
    NSLog(@"Binding Cordova callback for messages");
    
    callbackId = command.callbackId;
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

-(void)sendEvent:(NSDictionary *)eventData {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:eventData];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

-(void)onSendNativeMessage:(NSNotification*)notification {
    [self sendEvent:notification.userInfo];
}

-(void)pluginInitialize {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSendNativeMessage:) name:kSendNativeMessageNotification object:nil];
}

-(void)dispose {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
