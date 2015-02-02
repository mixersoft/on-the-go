//
//  PhotosUploader.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 12/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "PhotosUploader.h"
#import <Photos/Photos.h>
#import "NSOperationQueue+SynchronousOperation.h"

static NSString *parseApplicationID = @"cS8RqblszHpy6GJLAuqbyQF7Lya0UIsbcxO8yKrI";
static NSString *parseRESTAPIKey = @"3n5AwFGDO1n0YLEa1zLQfHwrFGpTnQUSZoRrFoD9";

static NSString *sessionIdentifierKey = @"com.on-the-go.PhotosUploaderSessionIdentifier";

static NSMutableSet *scheduledTasks;
static NSOperationQueue *serialQueue;


@interface PhotosUploader () <NSURLSessionTaskDelegate, NSURLSessionDelegate, NSURLSessionDataDelegate>

@end
@implementation PhotosUploader {
    NSURLSession *_backgroundUploadSession;
    NSHashTable *_delegates;
    NSMutableDictionary *_responseDataWrappers;
    PHImageManager *_cachingImageManager;
}

- (void)creteNewSession:(NSString *)identifier {
    
    [serialQueue addBlock:^(void(^operation)(void)) {
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        [config setDiscretionary:YES];
        [config setAllowsCellularAccess:YES];
        [config setSessionSendsLaunchEvents:YES];
        
        _backgroundUploadSession = [NSURLSession sessionWithConfiguration:config delegate:(id<NSURLSessionDelegate>)self delegateQueue:[NSOperationQueue mainQueue]];
        
        _delegates = [NSHashTable hashTableWithOptions:NSHashTableWeakMemory];
        _responseDataWrappers = [NSMutableDictionary new];
        [_backgroundUploadSession getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
           
            [uploadTasks enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [scheduledTasks addObject:obj];
            }];
            operation();
        }];
    }];
}

+(void)load {
    [super load];
    serialQueue = [NSOperationQueue createSerialQueue];
    scheduledTasks = [NSMutableSet new];
}

-(instancetype)initInternalWithIdentifier:(NSString *)identifier {
    if (self = [super init]) {
        _cachingImageManager = [PHImageManager new];
        NSData *prefsData = [NSUserDefaults.standardUserDefaults objectForKey:@"prefs"];
        [self setAllowsCellularAccess:NO];
        if (prefsData) {
            id prefs = [NSJSONSerialization JSONObjectWithData:prefsData options:0 error:nil];
            BOOL allowsCell = [[prefs objectForKey:@"upload"][@"use-cellular-data"] boolValue];
             [self setAllowsCellularAccess:allowsCell];
        }
       
        [self creteNewSession:identifier];
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
    PhotosUploader *u = self.instances[identifier];
    if (!u) {
        u = [[self alloc] initInternalWithIdentifier:identifier];
        self.instances[identifier] = u;
    }
    
    return u;
}

+(PhotosUploader *)sharedInstance {
    return [self uploaderWithSessionConfigurationIdentifier:sessionIdentifierKey];
}

-(void)setAllowsCellularAccess:(BOOL)allowsCellularAccess {
    if (_allowsCellularAccess == allowsCellularAccess) {
        return;
    }
#warning create session
    
}

- (NSString *)applicationDocumentsDirectory {
    return [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                   inDomains:NSUserDomainMask] lastObject] path];
}

- (NSString *) uploaderStoreDirectory
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        
        path = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"PhotosUploadStore"];
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

-(void)currentlyScheduledAssetIDs:(void(^)(NSArray *))completion {
    if (!completion) return;
    
    [serialQueue addBlock:^(void(^operation)(void)) {
        NSMutableArray *assets = [NSMutableArray arrayWithCapacity:scheduledTasks.count];
        [scheduledTasks enumerateObjectsUsingBlock:^(NSURLSessionUploadTask *obj, BOOL *stop) {
            NSString *identifier = obj.originalRequest.allHTTPHeaderFields[@"X-Image-Identifier"];
            if (!identifier.length) return;
            
            [assets addObject:identifier];
        }];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            completion(assets);
        }];
    }];
}


-(NSString *)imagePathForAssetIdentifier:(NSString *)identifier {
    NSString *name = [[[identifier componentsSeparatedByString:@"/"] firstObject] stringByAppendingPathExtension:@"jpg"];
    NSString *fullPath = [self.uploaderStoreDirectory stringByAppendingPathComponent:name];
    return fullPath;
}

-(void)unscheduleAssetsWithIdentifiers:(NSArray *)localPHAssetIdentifiers {
    [localPHAssetIdentifiers enumerateObjectsUsingBlock:^(NSString * obj, NSUInteger idx, BOOL *stop) {
        [self stopUploadingAssetWithID:obj completion:nil];
    }];
}

-(void)unscheduleAllAssets {
    [serialQueue addBlock:^(void(^operation)(void)) {
        [scheduledTasks enumerateObjectsUsingBlock:^(NSURLSessionUploadTask *obj, BOOL *stop) {
            if (obj.state == NSURLSessionTaskStateRunning) {
                [obj cancel];
            }
        }];
    }];
}

-(BOOL)isAssetScheduled:(PHAsset *)asset {
    NSSet *t = [scheduledTasks filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"localIdentifier == %@", asset.localIdentifier]];
    return t.count > 0;
}

-(void)scheduleAssetsWithIdentifiers:(NSArray *)localPHAssetIdentifiers options:(NSDictionary *)options {
    PHFetchResult *assets = [PHAsset fetchAssetsWithLocalIdentifiers:localPHAssetIdentifiers options:nil];
    
    NSLog(@"Assets Count: %lu", (unsigned long)localPHAssetIdentifiers.count);
    
    [serialQueue addBlock:^(void(^operation)(void)) {
        [assets enumerateObjectsUsingBlock:^(PHAsset *obj, NSUInteger idx, BOOL *stop) {
            BOOL alreadyScheduled = [self isAssetScheduled:obj];
            if (alreadyScheduled) {
                return;
            }

            //get image
            PHImageRequestOptions *opts = [PHImageRequestOptions new];
            [opts setDeliveryMode:PHImageRequestOptionsDeliveryModeHighQualityFormat];
            [opts setVersion:PHImageRequestOptionsVersionOriginal];
            [opts setResizeMode:PHImageRequestOptionsResizeModeExact];
            [opts setProgressHandler:^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
                
            }];
            
            CGSize originalImageSize = CGSizeMake(obj.pixelWidth, obj.pixelHeight);
            NSNumber *maxWidth = options[@"maxWidth"];
            if (maxWidth && obj.pixelWidth > maxWidth.floatValue) {
                CGFloat scale = (maxWidth.floatValue / obj.pixelWidth);
                originalImageSize = CGSizeApplyAffineTransform(originalImageSize, CGAffineTransformMakeScale(scale, scale));
            }
            [_cachingImageManager requestImageForAsset:obj targetSize:originalImageSize contentMode:PHImageContentModeAspectFit options:opts resultHandler:^(UIImage *result, NSDictionary *info) {
                if ([info[PHImageResultIsDegradedKey] boolValue]) {
                    return;
                }
                NSData *data = UIImageJPEGRepresentation(result, 1);
                
                if (data.length) {
                    //store image
                    NSString *fullPath = [self imagePathForAssetIdentifier:obj.localIdentifier];
                    if (![data writeToFile:fullPath atomically:YES])
                        return;
                    
                    NSLog(@"image:%@ with size:%@", fullPath.lastPathComponent, NSStringFromCGSize(result.size));
                    NSString *path = [NSString stringWithFormat:@"https://api.parse.com/1/files/%@", fullPath.lastPathComponent];
                    //NSString *path = [NSString stringWithFormat:@"http://151.237.16.170:1337/files/%@", fullPath.lastPathComponent];
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
                    [request setHTTPMethod:@"POST"];
                    [request addValue:parseApplicationID forHTTPHeaderField:@"X-Parse-Application-Id"];
                    [request addValue:parseRESTAPIKey forHTTPHeaderField:@"X-Parse-REST-API-Key"];
                    [request addValue:@"image/jpeg" forHTTPHeaderField:@"Content-Type"];
                    [request addValue:obj.localIdentifier forHTTPHeaderField:@"X-Image-Identifier"];
                    
                    NSURLSessionUploadTask *task = [_backgroundUploadSession uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:fullPath]];
                    [task resume];
                    [scheduledTasks addObject:task];
                    
                    for (id<PhotosUploaderDelegate>delegate in _delegates) {
                        if ([delegate respondsToSelector:@selector(photoUploader:didScheduleUploadForAssetWithIdentifier:)]) {
                            [delegate photoUploader:self didScheduleUploadForAssetWithIdentifier:obj.localIdentifier];
                        }
                    }
                }
            }];
            
        }];
        
    }];
}

-(void)stopUploadingAssetWithID:(NSString *)assetID completion:(void(^)(bool fond))completion {
    
    __block BOOL found = NO;
    [serialQueue addBlock:^(void(^operation)(void)) {
        
        [scheduledTasks enumerateObjectsUsingBlock:^(NSURLSessionUploadTask *obj, BOOL *stop) {
            NSString *identifier = obj.originalRequest.allHTTPHeaderFields[@"X-Image-Identifier"];
            if ([identifier isEqualToString:assetID]) {
                *stop = found = YES;
                [obj cancel];
                [self deleteDataForTask:obj];
            }
        }];
        
        if (completion) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                completion(found);
            }];
        }
    }];
}

-(NSData *)responseDataForTask:(NSURLSessionTask *)task {
     NSString *identifier = task.originalRequest.allHTTPHeaderFields[@"X-Image-Identifier"];
    NSMutableData *data = [_responseDataWrappers objectForKey:identifier];
    if (!data.length) {
        data = [NSMutableData dataWithContentsOfURL:[self fileURLOfDataForTask:task]];
    }
    return  data;
}

-(NSURL *)fileURLOfDataForTask:(NSURLSessionTask *)task {
    NSString *identifier = task.originalRequest.allHTTPHeaderFields[@"X-Image-Identifier"];
    if (!identifier.length) return nil;
    
     NSString *dir = [[self uploaderStoreDirectory] stringByAppendingPathComponent:[identifier stringByReplacingOccurrencesOfString:@"/" withString:@"-" options:NSCaseInsensitiveSearch range:NSMakeRange(0, identifier.length)]];
    return [NSURL fileURLWithPath:dir];
}

-(BOOL)appendData:(NSData *)data toTask:(NSURLSessionTask *)task {
    //NSFileWrapperReadingImmediate
    bool success = YES;
     NSString *identifier = task.originalRequest.allHTTPHeaderFields[@"X-Image-Identifier"];
    NSMutableData *_data = [_responseDataWrappers objectForKey:identifier];
    if (!_data) {
        //create wrapper
        
        _data = [NSMutableData data];
        [_responseDataWrappers setObject:_data forKey:identifier];
    }
    [_data appendData:data];
    NSError *error;
    [_data writeToURL:[self fileURLOfDataForTask:task] options:NSDataWritingAtomic error:&error];
    success = error == nil;
    
    return success;
}

-(void)deleteDataForTask:(NSURLSessionTask *)task {
    
    [serialQueue addBlock:^(void(^operation)(void)) {
        NSString *identifier = task.originalRequest.allHTTPHeaderFields[@"X-Image-Identifier"];
        //delete data
        [_responseDataWrappers removeObjectForKey:identifier];
        [NSFileManager.defaultManager removeItemAtURL:[self fileURLOfDataForTask:task] error:nil];
        NSString *path = [self imagePathForAssetIdentifier:identifier];
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        
        [scheduledTasks removeObject:task];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            for (id<PhotosUploaderDelegate>delegate in _delegates) {
                if ([delegate respondsToSelector:@selector(photoUploader:didCancelUploadAssetIdentifier:)]) {
                    [delegate photoUploader:self didCancelUploadAssetIdentifier:identifier];
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
    NSData *responseData = [self responseDataForTask:task];
    [self deleteDataForTask:task];
    NSLog(@"Finished task with image identifier: %@ responseDataLength: %lu with error:%@", identifier, (unsigned long)responseData.length, error);

    for (id<PhotosUploaderDelegate>delegate in _delegates) {
        if ([delegate respondsToSelector:@selector(photoUploader:didFinishUploadAssetIdentifier:responseData:withError:)]) {
            [delegate photoUploader:self didFinishUploadAssetIdentifier:identifier responseData:responseData withError:error];
        }
    }
    UILocalNotification* n1 = [[UILocalNotification alloc] init];
    n1.fireDate = [[NSDate date] dateByAddingTimeInterval:1];
    n1.alertBody = error ? @"Image Uploaded With Error" : @"Image Uploaded";
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
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
//didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
// completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
//     NSURLCredential *cred = [NSURLCredential credentialWithUser:@"browser" password:@"password" persistence:NSURLCredentialPersistenceForSession];
//    completionHandler(NSURLSessionAuthChallengeUseCredential, cred);
//    
//}

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
    
    [self appendData:data toTask:dataTask];
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

-(void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    for (id<PhotosUploaderDelegate>delegate in _delegates) {
        if ([delegate respondsToSelector:@selector(photoUploaderFinishedProcessingBackgroundEvents:)]) {
            [delegate photoUploaderFinishedProcessingBackgroundEvents:self];
        }
    }
}

@end
