//
//  SynchronousOperation.h
//  on-the-go
//
//  Created by Jimmy Ostoich on 17/10/14.
//  Copyright (c) 2014 Snaphappi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SynchronousOperation : NSOperation

@property (nonatomic, copy) void (^runOperation)(void(^operation)(void));

@end
