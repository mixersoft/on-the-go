//
//  SynchronousOperation.m
//  on-the-go
//
//  Created by Jimmy Ostoich on 17/10/14.
//  Copyright (c) 2014 Snaphappi. All rights reserved.
//

#import "SynchronousOperation.h"

@interface SynchronousOperation ()


@end

@implementation SynchronousOperation {
    BOOL        executing;
    BOOL        finished;
}

+(instancetype)operationWithRunBlock:(void (^)(void(^operation)(void)))block {
    id op = [[self alloc] init];
    [op setRunOperation:block];
    return op;
}

- (id)init {
    self = [super init];
    if (self) {
        executing = NO;
        finished = NO;
    }
    return self;
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return executing;
}

- (BOOL)isFinished {
    return finished;
}

- (void)start {
    // Always check for cancellation before launching the task.
    if ([self isCancelled])
    {
        // Must move the operation to the finished state if it is canceled.
        [self willChangeValueForKey:@"isFinished"];
        finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    // If the operation is not canceled, begin executing the task.
    [self willChangeValueForKey:@"isExecuting"];
    executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self main];
}

- (void)main {
    if (!self.runOperation) {
        [self  completeOperation];
        return;
    }
    
    self.runOperation(^{
        [self completeOperation];
    });
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    
    executing = NO;
    finished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

@end
