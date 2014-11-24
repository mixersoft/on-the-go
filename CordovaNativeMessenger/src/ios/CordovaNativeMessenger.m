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
    
    [self.commandDelegate runInBackground:^{
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
    }];
    
}

-(void)getPhotoById:(CDVInvokedUrlCommand*) command {
    
    __weak __typeof(self) weakself = self;
    [weakself.commandDelegate runInBackground:^{
    
        NSArray *identifiers;
        
        NSObject *arg0 = command.arguments[0];
        if([arg0 isKindOfClass:[NSString class]]) {
            identifiers = @[command.arguments.firstObject];
        } else if([arg0 isKindOfClass:[NSArray class]]) {
            identifiers = (NSArray*)arg0;
        }
        
        __block NSUInteger requestsLeft = identifiers.count;
        
        PHFetchResult *fetchResults = [PHAsset fetchAssetsWithLocalIdentifiers:identifiers options:nil];
        
        if(fetchResults.count != identifiers.count) {
            NSMutableArray *missingObjects = [identifiers mutableCopy];
            for(PHAsset *asset in fetchResults) {
                [missingObjects removeObject:asset.localIdentifier];
            }
            
            for(NSString *identifier in missingObjects) {
                CDVPluginResult *pluginResult = [CDVPluginResult
                                                 resultWithStatus:CDVCommandStatus_ERROR
                                                 messageAsDictionary:@{@"UUID":identifier,
                                                                       @"message":@"Not found!"}];
                
                pluginResult.keepCallback = @(requestsLeft > 1);
                --requestsLeft;
                
                [weakself.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

            }
        }
        
        NSNumber *width = command.arguments[1];
        NSNumber *height = command.arguments[2];
        
        CGSize imageSize = CGSizeMake([width doubleValue], [height doubleValue]);
        
        NSMutableArray *imageRequests = [[NSMutableArray alloc] initWithCapacity:[identifiers count]];
        for(PHAsset *asset in fetchResults) {
            PHImageRequestID request = [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:imageSize contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
                
                NSUInteger index = [imageRequests indexOfObject:info[PHImageResultRequestIDKey]];
                if(index == NSNotFound) {
                    NSLog(@"Warning: received orphaned image request. Should not be happening.");
                    return;
                }
                
                NSString *identifier = [fetchResults[index] localIdentifier];
                
                if(info[PHImageErrorKey]) {
                    NSError *err = info[PHImageErrorKey];
                    CDVPluginResult *pluginResult = [CDVPluginResult
                                                     resultWithStatus:CDVCommandStatus_ERROR
                                                     messageAsDictionary:@{@"UUID":identifier,
                                                                           @"message":err.localizedDescription}];
                    
                    pluginResult.keepCallback = @(requestsLeft > 1);
                    --requestsLeft;

                    
                    [weakself.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                    return;
                }
                
                
                NSData *bytes = UIImageJPEGRepresentation(result, 1);
                NSString *base64 = [bytes base64Encoding];
                
                if(base64 == nil) {
                    CDVPluginResult *pluginResult = [CDVPluginResult
                                                     resultWithStatus:CDVCommandStatus_ERROR
                                                     messageAsDictionary:@{@"UUID":identifier,
                                                                           @"message":@"Base64 encoding failed"}];
                    
                    pluginResult.keepCallback = @(requestsLeft > 1);
                    --requestsLeft;

                    
                    [weakself.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                    return;
                }
                
                NSString *withMIME = [@"data:image/jpg;base64," stringByAppendingString:base64];
                
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                              messageAsDictionary:@{@"UUID":identifier,
                                                                                    @"data":withMIME}];
                pluginResult.keepCallback = @(requestsLeft > 1);
                --requestsLeft;
                
                [weakself.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }];
            [imageRequests addObject:@(request)];
        }
        
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
