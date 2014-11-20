//
//  CordovaNativeMessenger.m
//  on-the-go
//
//  Created by Ivaylo Dankolov on 11/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "CordovaNativeMessenger.h"

#import <Photos/Photos.h>

NSString *kSendNativeMessageNotification = @"com.mixersoft.on-the-go.SendNativeMessageNotification";

#define PLUGIN_ERROR(message) [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: message]

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

-(void)mapAssetsLibrary:(CDVInvokedUrlCommand*) command {
    PHFetchResult *assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    
    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:assets.count];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    
    for(PHAsset *asset in assets) {
        [resultArray addObject:@{@"UUID":asset.localIdentifier,
                                 @"dateTaken":[dateFormatter stringFromDate:asset.creationDate]}];
    }
    
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:resultArray];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

-(void)getPhotoById:(CDVInvokedUrlCommand*) command {
    
    NSString *identifier = command.arguments[0];
    
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[identifier] options:nil];
    
    if(fetchResult.count == 0) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Image not found"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        
        return;
    }
    
    NSNumber *width = command.arguments[1];
    NSNumber *height = command.arguments[2];
    
    CGSize imageSize = CGSizeMake([width doubleValue], [height doubleValue]);
    
    PHAsset *asset = [fetchResult firstObject];
    
    
    __weak __typeof(self) weakself = self;
    
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:imageSize contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
        
        if(result == nil) {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Unable to read image"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
        
        [weakself.commandDelegate runInBackground:^{
            NSData *bytes = UIImageJPEGRepresentation(result, 1);
            NSString *base64 = [bytes base64Encoding];
            
            
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                    messageAsDictionary:@{@"UUID":identifier,
                                                                          @"data":base64}];
            
            [weakself.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
        
    }];
    
    
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
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        
    }];
}

-(void)dispose {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
