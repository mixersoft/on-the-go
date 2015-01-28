//
//  CordovaNativeMessenger.m
//  on-the-go
//
//  Created by Ivaylo Dankolov on 11/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "CordovaNativeMessenger.h"
#import "PhotosUploader.h"
#import <Photos/Photos.h>
#import <CoreLocation/CoreLocation.h>

NSString *kSendNativeMessageNotification = @"com.mixersoft.on-the-go.SendNativeMessageNotification";

NSString *kCommandKey = @"command";
NSString *kDataKey = @"data";

// commands
NSString *kPhotoStreamChangeCommandValue = @"photoStreamChange";

NSString *kScheduleAssetsForUploadCommandValue = @"scheduleAssetsForUpload";
NSString *kUnscheduleAssetsForUploadCommandValue = @"unscheduleAssetsForUpload";
NSString *kScheduleDayRangeForUploadCommandValue = @"scheduleDayRangeForUpload";
NSString *kUnscheduleDayRangeForUploadCommandValue = @"unscheduleDayRangeForUpload";

NSString *kDidBeginAssetUploadCommandValue = @"didBeginAssetUpload";
NSString *kDidFinishAssetUploadCommandValue = @"didFinishAssetUpload";
NSString *kDidUploadAssetProgressCommandValue = @"didUploadAssetProgress";

NSString *kLastImageAssetIDCommandValue = @"lastImageAssetID";

//Responds
NSString *kLastImageAssetIDResponseValue = @"lastImageAssetID";

NSString *kScheduleAssetsForUploadResponseValue = @"scheduleAssetsForUpload";

#define PLUGIN_ERROR(message) [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: message]

@interface CordovaNativeMessenger () <PhotosUploaderDelegate> {
    NSString *callbackId;
    NSDateFormatter *dateFormatter;
}

@end

@implementation CordovaNativeMessenger

+(NSMutableSet *)responders {
    NSMutableSet *_r = nil;
    if (!_r) {
        _r = [NSMutableSet new];
    }
    return _r;
}

+(void)addResponseBlock:(void(^)(NSString *command, id data))responceBlock {
    if (!responceBlock) return;
    
    [self.responders addObject:responceBlock];
}

-(void)getScheduledAssets:(CDVInvokedUrlCommand*) command {
    [PhotosUploader.sharedInstance currentlyScheduledAssetIDs:^(NSArray *scheduledIDS) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:scheduledIDS];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

-(void)scheduleAssetsForUpload:(CDVInvokedUrlCommand*) command {
    
    NSDictionary *data = command.arguments.firstObject;
    NSArray *assets = data[@"assets"];
    NSDictionary *options = data[@"options"];
    
    [PhotosUploader.sharedInstance scheduleAssetsWithIdentifiers:assets options:options];
    
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
}

-(void)unscheduleAssetsForUpload:(CDVInvokedUrlCommand*) command {
    
    NSDictionary *data = command.arguments.firstObject;
    NSArray *assets = data[@"assets"];
    [PhotosUploader.sharedInstance unscheduleAssetsWithIdentifiers:assets];
    
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
}

-(void)bindListener:(CDVInvokedUrlCommand*) command {
    NSLog(@"Binding Cordova callback for messages");
    
    callbackId = command.callbackId;
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

+(NSDateFormatter *)dateFormatter {
    static NSDateFormatter *_formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _formatter = [[NSDateFormatter alloc]init];
        [_formatter setDateFormat:@"yyyy-MM-dd"];
    });
    return _formatter;
}

-(void)mapCollections:(CDVInvokedUrlCommand*) command {
 //ToDO: map the list of collections with label, date range and array of images ( "PHFetchResult" )
    [self.commandDelegate runInBackground:^{
        PHFetchOptions *options = [PHFetchOptions new];
        [options setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:NO]]];
        
        NSMutableArray *_moments = [NSMutableArray new];
        
        PHFetchResult *collections = [PHCollectionList fetchMomentListsWithSubtype:PHCollectionListSubtypeMomentListCluster options:options];
        for (PHCollectionList * collection in collections) {
            
            PHFetchResult * momentsInCollection = [PHCollection fetchCollectionsInCollectionList:collection options:options];
            [momentsInCollection enumerateObjectsUsingBlock:^(PHAssetCollection * momentsAssetCollection, NSUInteger idx, BOOL *stop) {
                PHFetchOptions *op = [PHFetchOptions new];
                [op setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]]];
                [op setPredicate:[NSPredicate predicateWithFormat:@"(mediaType = %d)", PHAssetMediaTypeImage]];
                PHFetchResult *result = [PHAsset fetchAssetsInAssetCollection:momentsAssetCollection options:op];
                
                if (!result.count) {
                    return;
                }
                
                NSMutableDictionary *moment = [NSMutableDictionary new];
                
                NSMutableDictionary *momentInfoDict = [@{
                                                        @"assetCollectionType" : @(momentsAssetCollection.assetCollectionType),
                                                        @"assetCollectionSubtype" : @(momentsAssetCollection.assetCollectionSubtype),
                                                        @"estimatedAssetCount" : @(momentsAssetCollection.estimatedAssetCount),
                                                        @"startDate" : [self.class.dateFormatter stringFromDate:momentsAssetCollection.startDate],
                                                        @"endDate" : [self.class.dateFormatter stringFromDate:momentsAssetCollection.endDate],
                                                        
                                                        } mutableCopy];
                if (momentsAssetCollection.approximateLocation) {
                    [momentInfoDict setObject:@(momentsAssetCollection.approximateLocation.coordinate.latitude) forKey:@"approximateLocationLatitude"];
                    [momentInfoDict setObject:@(momentsAssetCollection.approximateLocation.coordinate.longitude) forKey:@"approximateLocationLongitude"];
                }
                if (momentsAssetCollection.localizedLocationNames.count) {
                    [momentInfoDict setObject:momentsAssetCollection.localizedLocationNames forKey:@"localizedLocationNames"];
                }
                if (momentsAssetCollection.localizedTitle.length) {
                    [momentInfoDict setObject:momentsAssetCollection.localizedTitle forKey:@"localizedTitle"];
                }
                
                [moment setObject:momentInfoDict forKey:@"momentInfo"];
                
                [moment setObject:result forKey:@"assets"];
                NSMutableArray *assetArray = [NSMutableArray new];
                for(PHAsset *asset in result) {
                    NSMutableDictionary *assetDict = [@{
                                                        @"UUID":asset.localIdentifier,
                                                        @"mediaType":@(asset.mediaType),
                                                        @"mediaSubTypes":@(asset.mediaSubtypes),
                                                        @"hidden":@(asset.hidden),
                                                        @"favorite":@(asset.favorite),
                                                        @"originalWidth":@(asset.pixelWidth),
                                                        @"originalHeight":@(asset.pixelHeight),
                                                        } mutableCopy];
                    if (datet) {
                        <#statements#>
                    }
                    
                    [assetArray addObject:@{
                                             @"dateTaken":[dateFormatter stringFromDate:asset.creationDate],
                                             @"burstIdentifier":asset.burstIdentifier,
                                             @"burstSelectionTypes":@(asset.burstSelectionTypes),
                                             @"representsBurst":@(asset.representsBurst)
                                             }];
                }
                [moment setObject:assetArray forKey:@"assets"];
                
                [_moments addObject:moment];
            }];
        }
        
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:_moments];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
    }];
    
    
    // test image change notifications
}

-(void)mapAssetsLibrary:(CDVInvokedUrlCommand*) command {
    
    [self mapCollections:command];
    
    [self.commandDelegate runInBackground:^{
        PHFetchOptions *opts = [PHFetchOptions new];
        opts.includeAllBurstAssets = YES;
        PHFetchResult *assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:opts];
        
        NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:assets.count];
        
        
        
        for(PHAsset *asset in assets) {
            // [resultArray addObject:@{@"UUID":asset.localIdentifier,
            //                          @"dateTaken":[dateFormatter stringFromDate:asset.creationDate]}];
            [resultArray addObject:@{
                    @"UUID":asset.localIdentifier,
                    @"dateTaken":[dateFormatter stringFromDate:asset.creationDate],
                    // @"UIImageOrientation":@(asset.imageOrientation),
                    @"mediaType":@(asset.mediaType),
                    @"mediaSubTypes":@(asset.mediaSubtypes),
                    @"hidden":@(asset.hidden),
                    @"favorite":@(asset.favorite),
                    @"originalWidth":@(asset.pixelWidth),
                    @"originalHeight":@(asset.pixelHeight),
                    @"burstIdentifier":asset.burstIdentifier,
                    @"burstSelectionTypes":@(asset.burstSelectionTypes),
                    @"representsBurst":@(asset.representsBurst)
                }];
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
                   NSString *base64 = [bytes base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
                    
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
                    // return UIImageOrientation property
                    jsonResult[@"UIImageOrientation"] = @(result.imageOrientation);
                    
                    if(autoRotate && [weakself isPortraitImage:result]) {
                        // jsonResult[@"originalWidth"] = @(asset.pixelHeight);
                        // jsonResult[@"originalHeight"] = @(asset.pixelWidth);
                        // asset dimensions are correct after autoRotate
                        jsonResult[@"originalWidth"] = @(asset.pixelWidth);
                        jsonResult[@"originalHeight"] = @(asset.pixelHeight);
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

-(void)unscheduleAllAssets:(CDVInvokedUrlCommand*) command {
    [PhotosUploader.sharedInstance unscheduleAllAssets];
    
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
}

-(void)suspendAllAssetUploads:(CDVInvokedUrlCommand*) command {
    [PhotosUploader.sharedInstance suspendAllAssetUploadsWithCompletion:^(NSArray *resultArray) {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:resultArray];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
    }];
}

-(void)resumeAllAssetUploads:(CDVInvokedUrlCommand*) command {
    [PhotosUploader.sharedInstance resumeAllAssetUplaodsWithCompletion:^(NSArray *resultArray) {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:resultArray];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
    }];
}

-(void)sendEvent:(NSDictionary *)eventData {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:eventData];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

-(void)pluginInitialize {
    
    dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    __weak CordovaNativeMessenger *_self = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:kSendNativeMessageNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [_self sendEvent:note.userInfo];
    }];
    
    [PhotosUploader.sharedInstance addDelegate:(id<PhotosUploaderDelegate>)self];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        
    }];
}


-(void)dispose {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [PhotosUploader.sharedInstance removeDelegate:(id<PhotosUploaderDelegate>)self];
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

+(void)sendMessage:(NSDictionary*)data WithCommand:(NSString*)command {
    
    NSDictionary *userInfo = @{
                               kCommandKey: command,
                               kDataKey : data
                               };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSendNativeMessageNotification object:self userInfo:userInfo];
}



#pragma mark PhotosUploaderDelegate

-(void)photoUploader:(PhotosUploader *)uploader didCancelUploadAssetIdentifier:(NSString *)assetIdentifier {
    [self.class sendMessage:@{@"assets":@[assetIdentifier]} WithCommand:kUnscheduleAssetsForUploadCommandValue];
}

-(void)photoUploader:(PhotosUploader *)uploader didFinishUploadAssetIdentifier:(NSString *)assetIdentifier responseData:(NSData *)data withError:(NSError *)error state:(NSURLSessionTaskState)state {
    
    NSMutableDictionary *dict = [@{@"asset":assetIdentifier, @"success":@(error==nil), @"state":@(state)} mutableCopy];
    if (!error) {
        NSError *parseError = nil;
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&parseError];
        [dict addEntriesFromDictionary:d];
        [dict setObject:@(parseError==nil) forKey:@"success"];
    }
    [self.class sendMessage:dict WithCommand:kDidFinishAssetUploadCommandValue];
    
}

-(void)photoUploader:(PhotosUploader *)uploader didScheduleUploadForAssetWithIdentifier:(NSString *)assetIdentifier {
    [self.class sendMessage:@{@"asset":assetIdentifier} WithCommand:kDidBeginAssetUploadCommandValue];
}

-(void)photoUploader:(PhotosUploader *)uploader didUploadDataForAssetWithIdentifier:(NSString *)asseetIdentifier totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    
    [self.class sendMessage:@{
                              @"asset" : asseetIdentifier,
                              @"totalBytesSent" :@(totalBytesSent),
                              @"totalBytesExpectedToSend" : @(totalBytesExpectedToSend)
                              }
                WithCommand:kDidUploadAssetProgressCommandValue];
    
}

@end

