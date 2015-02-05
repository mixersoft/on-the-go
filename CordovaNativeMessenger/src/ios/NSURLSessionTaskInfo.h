//
//  NSURLSessionTaskInfo.h
//  On-the-Go
//
//  Created by Dimitar Ostoich on 2/5/15.
//
//

#import <Foundation/Foundation.h>

@interface NSURLSessionTaskInfo : NSObject <NSCoding>

@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSMutableData *data;

@property (nonatomic, readonly) BOOL hasFinished;


@end
