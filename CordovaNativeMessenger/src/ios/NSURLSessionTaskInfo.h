//
//  NSURLSessionTaskInfo.h
//  On-the-Go
//
//  Created by Dimitar Ostoich on 2/5/15.
//
//

#import <Foundation/Foundation.h>

@interface NSURLSessionTaskInfo : NSObject <NSCoding>

@property (nonatomic, strong) NSString *asset;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, assign) BOOL hasFinished;


@end
