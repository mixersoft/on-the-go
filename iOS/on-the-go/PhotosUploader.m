//
//  PhotosUploader.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 12/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "PhotosUploader.h"
@import Photos;
static NSString *parseApplicationID = @"Y9kGkaX2cbq6sh8NVZnslB9ZpwF4TbAEfFti7FQX";
static NSString *parseRESTAPIKey = @"q9OPhuoIMLfIzvGoBLpHqb6mdJnMMdGGCGZgKfqB";
static NSString *parseMasterKey = @"fsMgAw0ozmaZj5Kr9Tz8nuhPwNI1ZTLAsKeoojlP";

@interface PhotosUploader () <NSURLSessionTaskDelegate, NSURLSessionDelegate, NSURLSessionDataDelegate>

@end
@implementation PhotosUploader {
    NSURLSession *_backgroundUploadSession;
    NSHashTable *_delegates;
    NSMutableDictionary *_responseDataDict;
}

-(instancetype)initInternalWithIdentifier:(NSString *)identifier {
    if (self = [super init]) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        [config setDiscretionary:YES];
        [config setAllowsCellularAccess:YES];
        [config setSessionSendsLaunchEvents:YES];
        _backgroundUploadSession = [NSURLSession sessionWithConfiguration:config delegate:(id<NSURLSessionDelegate>)self delegateQueue:[NSOperationQueue mainQueue]];
        
        _delegates = [NSHashTable hashTableWithOptions:NSHashTableWeakMemory];
        _responseDataDict = [NSMutableDictionary new];
    }
    return self;
}

+(NSMutableDictionary *)instances {
    static NSMutableDictionary *_dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dict = [NSMutableDictionary new];
    });
    return _dict;
}

+(PhotosUploader *)uploaderWithSessionConfigurationIdentifier:(NSString *)identifier {
    if (!identifier.length) return nil;
    PhotosUploader *u = self.instances[@"identifier"] ?: [[self alloc] initInternalWithIdentifier:identifier];
    return u;
}

- (NSString *) applicationDocumentsDirectory
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        
        path = [basePath stringByAppendingString:@"PhotosUploadStore"];
        if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
            [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    return path;
}

-(void)addDelegate:(id<PhotosUploaderDelegate>)delegate {
    [_delegates addObject:delegate];
}

-(void)removeDelegate:(id<PhotosUploaderDelegate>)delegate {
    [_delegates removeObject:delegate];
}


-(NSString *)imagePathForAssetIdentifier:(NSString *)identifier {
    NSString *name = [[[identifier componentsSeparatedByString:@"/"] firstObject] stringByAppendingPathExtension:@"jpg"];
    NSString *fullPath = [self.applicationDocumentsDirectory stringByAppendingPathComponent:name];
    return fullPath;
}

-(void)scheduleAssetsWithIdentifiers:(NSArray *)localPHAssetIdentifiers {
    PHFetchResult *assets = [PHAsset fetchAssetsWithLocalIdentifiers:localPHAssetIdentifiers options:nil];
    PHImageManager *cachingImageManager = [PHImageManager new];
    NSLog(@"Assets Count: %d", assets.count);
    
    [assets enumerateObjectsUsingBlock:^(PHAsset *obj, NSUInteger idx, BOOL *stop) {
        //get image
        PHImageRequestOptions *opts = [PHImageRequestOptions new];
        [opts setDeliveryMode:PHImageRequestOptionsDeliveryModeHighQualityFormat];
        [opts setVersion:PHImageRequestOptionsVersionOriginal];
        [opts setResizeMode:PHImageRequestOptionsResizeModeExact];
        
        CGSize originalImageSize = CGSizeMake(obj.pixelWidth, obj.pixelHeight);
        CGFloat maxSide = MAX(originalImageSize.width, originalImageSize.height);
        
//        if (self.convertTo720p && maxSide > 720) {
//            CGFloat scale = (720.0 / maxSide);
//            originalImageSize = CGSizeApplyAffineTransform(originalImageSize, CGAffineTransformMakeScale(scale, scale));
//        }
        
        PHImageRequestID imageRequestID = [cachingImageManager requestImageForAsset:obj targetSize:originalImageSize contentMode:PHImageContentModeAspectFit options:opts resultHandler:^(UIImage *result, NSDictionary *info) {
            if ([info[PHImageResultIsDegradedKey] boolValue]) {
                return;
            }
            NSData *data = UIImageJPEGRepresentation(result, 1);
            [cachingImageManager cancelImageRequest:imageRequestID];
            
            if (data.length) {
                //store image
                NSString *fullPath = [self imagePathForAssetIdentifier:obj.localIdentifier];
                if (![data writeToFile:fullPath atomically:YES])
                    return;
                
                NSLog(@"image:%@ with size:%@", fullPath.lastPathComponent, NSStringFromCGSize(result.size));
                //NSString *path = [NSString stringWithFormat:@"https://api.parse.com/1/files/%@", fullPath.lastPathComponent];
                NSString *path = [NSString stringWithFormat:@"http://dev.mediastorm.bg:1337/files/%@", fullPath.lastPathComponent];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
                [request setHTTPMethod:@"POST"];
                [request addValue:parseApplicationID forHTTPHeaderField:@"X-Parse-Application-Id"];
                [request addValue:parseRESTAPIKey forHTTPHeaderField:@"X-Parse-REST-API-Key"];
                [request addValue:@"image/jpeg" forHTTPHeaderField:@"Content-Type"];
                [request addValue:obj.localIdentifier forHTTPHeaderField:@"X-Image-Identifier"];
            
                NSURLSessionUploadTask *task = [_backgroundUploadSession uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:fullPath]];
                [task resume];
                for (id<PhotosUploaderDelegate>delegate in _delegates) {
                    if ([delegate respondsToSelector:@selector(photoUploader:didScheduleUploadForAssetWithIdentifier:)]) {
                        [delegate photoUploader:self didScheduleUploadForAssetWithIdentifier:obj.localIdentifier];
                    }
                }
            }
        }];
    }];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    
    NSString *identifier = task.originalRequest.allHTTPHeaderFields[@"X-Image-Identifier"];
    for (id<PhotosUploaderDelegate>delegate in _delegates) {
        if ([delegate respondsToSelector:@selector(photoUploader:didUploadDataForAssetWithIdentifier:totalBytesSent:totalBytesExpectedToSend:)]) {
            [delegate photoUploader:self didUploadDataForAssetWithIdentifier:identifier totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
        }
    }
}

/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    NSString *identifier = task.originalRequest.allHTTPHeaderFields[@"X-Image-Identifier"];
    
    NSString *path = [self imagePathForAssetIdentifier:identifier];
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    NSData *responseData = _responseDataDict[identifier];
    [_responseDataDict removeObjectForKey:identifier];
    NSLog(@"Finished task with image identifier: %@ responseDataLength: %d with error:%@", identifier, responseData.length, error);
    
    for (id<PhotosUploaderDelegate>delegate in _delegates) {
        if ([delegate respondsToSelector:@selector(photoUploader:didUploadAssetIdentifier:responseData:withError:)]) {
            [delegate photoUploader:self didUploadAssetIdentifier:identifier responseData:responseData withError:error];
        }
    }
    UILocalNotification* n1 = [[UILocalNotification alloc] init];
    n1.fireDate = [[NSDate date] dateByAddingTimeInterval:1];
    n1.alertBody = @"Image Uploaded";
    [[UIApplication sharedApplication] scheduleLocalNotification: n1];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    completionHandler(NSURLSessionResponseBecomeDownload);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask {
    
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    
}

/* The task has received a request specific authentication challenge.
 * If this delegate is not implemented, the session specific authentication challenge
 * will *NOT* be called and the behavior will be the same as using the default handling
 * disposition.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    
}

/* Sent if a task requires a new, unopened body stream.  This may be
 * necessary when authentication has failed for any request that
 * involves a body stream.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
 needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler {
    
}


/* Sent when data is available for the delegate to consume.  It is
 * assumed that the delegate will retain and not copy the data.  As
 * the data may be discontiguous, you should use
 * [NSData enumerateByteRangesUsingBlock:] to access it.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    if(!data.length) return;
    
    NSString *identifier = dataTask.originalRequest.allHTTPHeaderFields[@"X-Image-Identifier"];
    NSMutableData *localData = _responseDataDict[identifier];
    if (!localData) {
        localData = [NSMutableData new];
        [_responseDataDict setObject:localData forKey:identifier];
    }
    [localData appendData:data];
    NSLog(@"%@",dataTask);
}

/* Invoke the completion routine with a valid NSCachedURLResponse to
 * allow the resulting data to be cached, or pass nil to prevent
 * caching. Note that there is no guarantee that caching will be
 * attempted for a given resource, and you should not rely on this
 * message to receive the resource data.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    
}

@end
