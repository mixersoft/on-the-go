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
    NSDateFormatter *dateFormatter;
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
        PHFetchOptions *opts = [PHFetchOptions new];
        opts.includeAllBurstAssets = YES;
        PHFetchResult *assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:opts];
        
        NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:assets.count];
        
        
        
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
            identifiers = @[command.arguments[0]];
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
        
        NSDictionary *options = command.arguments[1];
        
        NSNumber *width = options[@"targetWidth"];
        NSNumber *height = options[@"targetHeight"];
        NSString *resizeModeString = options[@"resizeMode"];
        BOOL autoRotate = [options[@"autoRotate"] boolValue];
        
        PHImageRequestOptions *requestOptions = [PHImageRequestOptions new];
        requestOptions.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
        requestOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
        
        PHImageContentMode resizeMode;
        if([resizeModeString isEqualToString:@"aspectFit"]) {
            resizeMode = PHImageContentModeAspectFit;
        } else if([resizeModeString isEqualToString:@"aspectFill"]) {
            resizeMode = PHImageContentModeAspectFill;
        } else {
            resizeMode = PHImageContentModeDefault;
        }
        
        CGSize imageSize = CGSizeMake([width doubleValue], [height doubleValue]);
        
        NSMutableArray *imageRequests = [[NSMutableArray alloc] initWithCapacity:[identifiers count]];
        for(PHAsset *asset in fetchResults) {
            PHImageRequestID request = [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:imageSize contentMode:resizeMode options:requestOptions resultHandler:^(UIImage *result, NSDictionary *info) {
                
                __block UIImage *resultImage = result;
                
                NSUInteger index = [imageRequests indexOfObject:info[PHImageResultRequestIDKey]];
                if(index == NSNotFound) {
                    NSLog(@"Warning: received orphaned image request. Should not be happening.");
                    return;
                }
                
                PHAsset *asset = fetchResults[index];
                NSString *identifier = [asset localIdentifier];
                
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
                
                
                [weakself.commandDelegate runInBackground:^{
                    
                    if(autoRotate) {
                        resultImage = [weakself rotateImageBasedOnEXIF:resultImage];
                    }
                    
                    NSData *bytes = UIImageJPEGRepresentation(resultImage, 1);
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
                    
                    NSMutableDictionary *jsonResult = [NSMutableDictionary new];
                    jsonResult[@"UUID"] = identifier;
                    jsonResult[@"data"] = withMIME;
                    jsonResult[@"dateTaken"] = [dateFormatter stringFromDate:[asset creationDate]];
                    
                    if(autoRotate && [weakself isPortraitImage:result]) {
                        jsonResult[@"originalWidth"] = @(asset.pixelHeight);
                        jsonResult[@"originalHeight"] = @(asset.pixelWidth);
                    } else {
                        jsonResult[@"originalWidth"] = @(asset.pixelWidth);
                        jsonResult[@"originalHeight"] = @(asset.pixelHeight);
                    }
                    
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                  messageAsDictionary:jsonResult];
                    pluginResult.keepCallback = @(requestsLeft > 1);
                    --requestsLeft;
                    
                    [weakself.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }];
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
    
    dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSendNativeMessage:) name:kSendNativeMessageNotification object:nil];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        
    }];
}

-(void)dispose {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(BOOL)isPortraitImage:(UIImage*)image{
    UIImageOrientation o = image.imageOrientation;
    return o == UIImageOrientationLeft
        || o == UIImageOrientationLeftMirrored
        || o == UIImageOrientationRight
        || o == UIImageOrientationRightMirrored;
    
}

-(UIImage*)rotateImageBasedOnEXIF:(UIImage*)original{
    
    
    if (original.imageOrientation == UIImageOrientationUp) return original;
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (original.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, original.size.width, original.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, original.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, original.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }
    
    switch (original.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, original.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, original.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, original.size.width, original.size.height,
                                             CGImageGetBitsPerComponent(original.CGImage), 0,
                                             CGImageGetColorSpace(original.CGImage),
                                             CGImageGetBitmapInfo(original.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (original.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,original.size.height,original.size.width), original.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,original.size.width,original.size.height), original.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

@end
