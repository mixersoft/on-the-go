//
//  PhotosUploadScheduler.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 12/16/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "PhotosUploadScheduler.h"
#import "PhotosSource.h"

static NSString *kToSendItemsName = @"ToSendItemsStore";
static NSString *kSentItemsName = @"SentItemsStore";

static size_t sizeOfShort = sizeof(short);

@implementation PhotosUploadScheduler {
    PhotosSource *_photosSource;
    int _toSendItemsFD;
    dispatch_io_t _sentItemsChannel;
    NSMutableSet *_toSendInMemorySet;
    NSMutableSet *_sentInMemorySet;
}

-(instancetype)init {
    if (self = [super init]) {
        _photosSource = [PhotosSource sharedInstance];

        [self loadData];
    }
    return self;
}

- (NSString *) applicationDocumentsDirectoryWithSubpath:(NSString *)subPath
{
    static NSString *appDir = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        appDir = basePath;
        NSLog(@"%@", appDir);
    });
    
    return [appDir stringByAppendingPathComponent:subPath];
}

-(NSMutableSet *)loadFileWithPath:(NSString *)path {
    NSMutableSet *set = [NSMutableSet new];
//    NSNumber* theSize;
//    NSInteger fileSize = 0;
//    if ([[NSURL fileURLWithPath:path] getResourceValue:&theSize forKey:NSURLFileSizeKey error:nil])
//        fileSize = [theSize integerValue];
//    
//    if (theSize == 0) {
//        return set;
//    }
//
    NSError *error;
    NSData*data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&error];
    size_t  currentOffset = 0;
    size_t fileSize = [data length];
    
//    
    
    
    while (currentOffset < fileSize) {
        short length;
        void *ptr = (void *)&length;
        bzero(&length, sizeOfShort);
        
        memcpy(ptr, data.bytes + currentOffset, sizeOfShort);
        if (length == 0) {
            return [NSMutableSet new];
        }
        currentOffset+=sizeOfShort;
        
        NSString *localIdentifier = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(currentOffset, length)] encoding:NSUTF8StringEncoding];
        [set addObject:localIdentifier];
        currentOffset+=length;
    }
    return set;
}

-(void)loadData {
    NSString *path = [self applicationDocumentsDirectoryWithSubpath:kToSendItemsName];
    _toSendInMemorySet = [self loadFileWithPath:path];
//    _toSendItemsChannel = dispatch_io_create_with_path(DISPATCH_IO_STREAM,
//                                                [path  UTF8String],   // Convert to C-string
//                                                O_CREAT|O_WRONLY,                // Open for reading
//                                                S_IREAD|S_IWUSR,                       // No extra flags
//                                                dispatch_get_main_queue(),
//                                                ^(int error){
//                                                    
//                                                    if (error == 0) {
//                                                        _toSendItemsChannel = NULL;
//                                                    }
//                                                });
    _toSendItemsFD = open([path UTF8String], O_CREAT|O_WRONLY|O_APPEND, S_IWRITE | S_IREAD );
    
    
    path = [self applicationDocumentsDirectoryWithSubpath:kSentItemsName];
    _sentInMemorySet = [self loadFileWithPath:path];
    _sentItemsChannel = dispatch_io_create_with_path(DISPATCH_IO_STREAM,
                                                       [path UTF8String],   // Convert to C-string
                                                       O_CREAT|O_WRONLY,                // Open for reading
                                                       S_IREAD|S_IWUSR, 
                                                       dispatch_get_main_queue(),
                                                       ^(int error){
                                                           
                                                           if (error == 0) {
                                                               _sentItemsChannel = NULL;
                                                           }
                                                       });
    

    
    NSUInteger count = _toSendInMemorySet.count;
    [_toSendInMemorySet minusSet:_sentInMemorySet];
    if (count != _toSendInMemorySet.count) {
        [self serialize];
    }
}

-(void)serialize {
    if (_toSendItemsFD >= 0) {
        close(_toSendItemsFD), _toSendItemsFD = -1;
    }
    //dispatch_io_close(_toSendItemsChannel,  DISPATCH_IO_STOP);
    dispatch_io_close(_sentItemsChannel, DISPATCH_IO_STOP);
    
    NSMutableData *data = [NSMutableData new];
    [_toSendInMemorySet enumerateObjectsUsingBlock:^(NSString *obj, BOOL *stop) {
        short length = obj.length;
        [data appendBytes:&length length:sizeOfShort];
        [data appendData:[obj dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    [data writeToFile:[self applicationDocumentsDirectoryWithSubpath:kToSendItemsName] atomically:YES];
    
    data = [NSMutableData new];
    [_sentInMemorySet enumerateObjectsUsingBlock:^(NSString *obj, BOOL *stop) {
        short length = obj.length;
        [data appendBytes:&length length:sizeOfShort];
        [data appendData:[obj dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    [data writeToFile:[self applicationDocumentsDirectoryWithSubpath:kSentItemsName] atomically:YES];
    
    [self loadData];
}

-(void)dealloc {
    if (_toSendItemsFD) {
        close(_toSendItemsFD), _toSendItemsFD = nil;
    }
}

-(void)addIdentifierToSend:(NSString *)localIdentifier {
    
    short length = localIdentifier.length;
    write(_toSendItemsFD, &length, sizeOfShort);
    NSData *data = [localIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    ssize_t size = write(_toSendItemsFD, data.bytes, data.length);
//    
//    dispatch_data_t data = dispatch_data_create(&length, sizeOfShort, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
//    
//    NSData *identifier = [localIdentifier dataUsingEncoding:NSUTF8StringEncoding];
//    data = dispatch_data_create_concat(data, dispatch_data_create(identifier.bytes, identifier.length, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT));
//    
//    [_toSendInMemorySet addObject:localIdentifier];
    
//    dispatch_io_write(_toSendItemsChannel, 0, data, dispatch_get_main_queue(), ^(bool done, dispatch_data_t data, int error) {
//        
//    });
    
//    int fileDescriptor;
//    fileDescriptor = open("./NewFile", O_CREAT, S_IRWXU|S_IRWXG|S_IRWXO );
//    printf("File Descriptor: %d\n", fileDescriptor);
//    close(fileDescriptor);
//    
//    write(_toSendItemsFD, <#const void *#>, <#size_t#>)
}

-(void)schedulePhotos:(PHFetchResult *)result {
    
}

-(void)scheduleDateRanggeFrom:(NSDate *)fromDate toDate:(NSDate *)toDate {
    
}

@end
