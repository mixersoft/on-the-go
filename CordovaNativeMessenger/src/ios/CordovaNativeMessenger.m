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
#import "UIImage+FixOrientation.h"

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
NSString *kDidFailToScheduleAssetCommandValue = @"didFailToScheduleAsset";

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

-(void)setAllowsCellularAccess:(CDVInvokedUrlCommand*)command {
    BOOL newCandidate = [[command argumentAtIndex:0] boolValue];
    [PhotosUploader.sharedInstance setAllowsCellularAccess:newCandidate];
}


-(void)mapCollections:(CDVInvokedUrlCommand*) command {    
   [self.commandDelegate runInBackground:^{
        PHFetchOptions *options = [PHFetchOptions new];
        options.includeAllBurstAssets = YES;
        [options setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:NO]]];
    
        NSMutableArray *_collections = [NSMutableArray new];
        
        PHFetchResult *s = [PHCollectionList fetchCollectionListsWithType:PHCollectionListTypeMomentList subtype:PHCollectionListSubtypeMomentListCluster options:options];
        
        for (PHCollectionList * collection in s) {
            
            NSMutableDictionary *collectionInfoDict = [@{
                                                         @"collectionListType" : @(collection.collectionListType),
                                                         @"collectionListSubtype" : @(collection.collectionListSubtype),
                                                         @"startDate" : [self.class.dateFormatter stringFromDate:collection.startDate],
                                                         @"endDate" : [self.class.dateFormatter stringFromDate:collection.endDate],
                                                         
                                                         } mutableCopy];
            if (collection.localizedLocationNames.count) {
                [collectionInfoDict setObject:collection.localizedLocationNames forKey:@"localizedLocationNames"];
            }
            if (collection.localizedTitle.length) {
                [collectionInfoDict setObject:collection.localizedTitle forKey:@"localizedTitle"];
            }
            
            [_collections addObject:collectionInfoDict];
            
            PHFetchResult *res = [PHAssetCollection fetchCollectionsInCollectionList:collection options:options];
            NSMutableArray *_moments = [NSMutableArray arrayWithCapacity:res.count];
            [collectionInfoDict setObject:_moments forKey:@"moments"];
            //fetch moments within collection
            for (PHAssetCollection *momentObj in res) {
                PHFetchOptions *op = [PHFetchOptions new];
                op.includeHiddenAssets = YES;
                [op setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]]];
                [op setPredicate:[NSPredicate predicateWithFormat:@"(mediaType = %d)", PHAssetMediaTypeImage]];
                PHFetchResult *result = [PHAsset fetchAssetsInAssetCollection:(PHAssetCollection *)momentObj options:op];
                
                if (!result.count) {
                    continue;
                }
                
                NSMutableDictionary *moment = [NSMutableDictionary new];
                
                moment[@"assetCollectionType"] = @(momentObj.assetCollectionType);
                moment[@"assetCollectionSubtype"] = @(momentObj.assetCollectionSubtype);
                moment[@"estimatedAssetCount"] = @(momentObj.estimatedAssetCount);
                moment[@"startDate"] = [self.class.dateFormatter stringFromDate:momentObj.startDate];
                moment[@"endDate"] = [self.class.dateFormatter stringFromDate:momentObj.endDate];

                if (momentObj.localizedLocationNames.count) {
                    [moment setObject:collection.localizedLocationNames forKey:@"localizedLocationNames"];
                 }
                 if (momentObj.localizedTitle.length) {
                     [moment setObject:collection.localizedTitle forKey:@"localizedTitle"];
                 }
                 
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
                                                         @"dateTaken":[dateFormatter stringFromDate:asset.creationDate],
                                                         @"burstSelectionTypes":@(asset.burstSelectionTypes),
                                                         @"representsBurst":@(asset.representsBurst)
                                                         } mutableCopy];
                     if (asset.burstIdentifier.length) {
                         [assetDict setObject:asset.burstIdentifier forKey:@"burstIdentifier"];
                     }
                     
                     [assetArray addObject:assetDict];
                     
                 }
                 [moment setObject:assetArray forKey:@"assets"];
                 [_moments addObject:moment];
                 
             }
         }
        
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:_collections];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
    }];
    
    // test image change notifications
}

-(void)mapAssetsLibrary:(CDVInvokedUrlCommand*) command {
    [self.commandDelegate runInBackground:^{
        PHFetchOptions *opts = [PHFetchOptions new];
        opts.includeAllBurstAssets = YES;
        PHFetchResult *assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:opts];
        
        NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:assets.count];
        
        for(PHAsset *asset in assets) {
            
            NSMutableDictionary *assetDict = [@{
                                                @"UUID":asset.localIdentifier,
                                                @"mediaType":@(asset.mediaType),
                                                @"mediaSubTypes":@(asset.mediaSubtypes),
                                                @"hidden":@(asset.hidden),
                                                @"favorite":@(asset.favorite),
                                                @"originalWidth":@(asset.pixelWidth),
                                                @"originalHeight":@(asset.pixelHeight),
                                                @"dateTaken":[dateFormatter stringFromDate:asset.creationDate],
                                                @"burstSelectionTypes":@(asset.burstSelectionTypes),
                                                @"representsBurst":@(asset.representsBurst)
                                                } mutableCopy];
            if (asset.burstIdentifier.length) {
                [assetDict setObject:asset.burstIdentifier forKey:@"burstIdentifier"];
            }
            
            [resultArray addObject:assetDict];
        }
        
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:resultArray];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
    }];
}

-(void)allSessionTaskInfos:(CDVInvokedUrlCommand*) command {
    NSMutableArray *arr = [NSMutableArray new];
    [[PhotosUploader.sharedInstance allSessionTaskInfos] enumerateObjectsUsingBlock:^(NSURLSessionTaskInfo *obj, NSUInteger idx, BOOL *stop) {
        [arr  addObject:@{
                          @"identifier" : obj.identifier,
                          @"progress" : @(obj.progress),
                          @"hasFinished" : @(obj.hasFinished),
                          @"errorCode" : @(obj.error.code),
                          @"success" : @(obj.error == nil)
                          }];
    }];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:arr];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

-(void)removeSessionTaskInfoWithIdentifier:(CDVInvokedUrlCommand*) command {
    NSString *str = command.arguments[0];
    BOOL success = [PhotosUploader.sharedInstance removeSessionTaskInfoWithIdentifier:str];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:success?CDVCommandStatus_OK:CDVCommandStatus_ERROR];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

-(void)sessionTaskInfoForIdentifier:(CDVInvokedUrlCommand*) command {
    NSString *str = command.arguments[0];
    NSURLSessionTaskInfo *obj = [PhotosUploader.sharedInstance sessionTaskInfoForIdentifier:str];
    if (!obj) {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
    }
    else {
        
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{
                                                                                                                     @"identifier" : obj.identifier,
                                                                                                                     @"progress" : @(obj.progress),
                                                                                                                     @"hasFinished" : @(obj.hasFinished),
                                                                                                                     @"errorCode" : @(obj.error.code),
                                                                                                                     @"success" : @(obj.error == nil)
                                                                                                                     }];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
    }
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
        
        PHFetchOptions *fetchOptions = [PHFetchOptions new];
        fetchOptions.includeAllBurstAssets = YES;
        fetchOptions.includeHiddenAssets = YES;
        PHFetchResult *fetchResults = [PHAsset fetchAssetsWithLocalIdentifiers:identifiers options:fetchOptions];
        
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
                        resultImage = [resultImage imageWithFixedOrientationSized:resultImage.size];
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
    [PhotosUploader.sharedInstance unscheduleAllAssetsWithCompletion:^{
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
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

-(void)photoUploader:(PhotosUploader *)uploader didFinishUploadAssetIdentifier:(NSString *)assetIdentifier {
    
//    NSMutableDictionary *dict = [@{@"asset":assetIdentifier, @"success":@(error == nil)} mutableCopy];
//    if (error) {
//        [dict setObject:@(NO) forKey:@"success"];
//        [dict setObject:@(error.code) forKey:@"errorCode"];
//    }
//    
//    if (data.length) {
//        NSError *parseError = nil;
//        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&parseError];
//        [dict addEntriesFromDictionary:d];
//    }
    
    [self.class sendMessage:@{@"asset":assetIdentifier} WithCommand:kDidFinishAssetUploadCommandValue];
    
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

-(void)photoUploader:(PhotosUploader *)uploader didFailToScheduleAssetIdentifier:(NSString *)assetIdentifier isMissing:(BOOL)isMissing error:(NSError *)error {
    NSMutableDictionary *dict = [@{@"asset" : assetIdentifier} mutableCopy];
    if (isMissing) {
        [dict setObject:@(isMissing) forKeyedSubscript:@"isMissing"];
    }
    if (error) {
        [dict setObject:@(error.code) forKeyedSubscript:@"errorCode"];
    }
    [self.class sendMessage:dict WithCommand:kDidFailToScheduleAssetCommandValue];
}

@end

