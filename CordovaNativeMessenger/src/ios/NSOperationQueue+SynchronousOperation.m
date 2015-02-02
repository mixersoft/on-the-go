//
//  NSOperationQueue+SynchronousOperation.m
//  on-the-go
//
//  Created by Jimmy Ostoich on 17/10/14.
//  Copyright (c) 2014 Snaphappi. All rights reserved.
//

#import "NSOperationQueue+SynchronousOperation.h"
#import "SynchronousOperation.h"

@implementation NSOperationQueue (SynchronousOperation)

+(NSOperationQueue *)createSerialQueue {
    
    NSOperationQueue *queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 1;
    return queue;
}

-(void)addBlock:(void(^)(void(^operation)(void)))block {

    SynchronousOperation *operation = [SynchronousOperation new];
    operation.runOperation = block;
    
    [self addOperation:operation];
}

@end
