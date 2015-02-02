//
//  NSOperationQueue+SynchronousOperation.h
//  on-the-go
//
//  Created by Jimmy Ostoich on 17/10/14.
//  Copyright (c) 2014 Snaphappi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSOperationQueue (SynchronousOperation)

+(NSOperationQueue *)createSerialQueue;

-(void)addBlock:(void(^)(void(^operation)(void)))block;

@end
