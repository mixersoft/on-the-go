//
//  NSURLSessionTaskInfo.m
//  On-the-Go
//
//  Created by Dimitar Ostoich on 2/5/15.
//
//

#import "NSURLSessionTaskInfo.h"

@implementation NSURLSessionTaskInfo


- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.asset forKey:@"asset"];
    [aCoder encodeFloat:self.progress forKey:@"progress"];
    [aCoder encodeObject:self.error forKey:@"error"];
    [aCoder encodeBool:self.hasFinished forKey:@"hasFinished"];
    [aCoder encodeObject:self.data forKey:@"data"];
    
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [self init]) {
        self.asset = [aDecoder decodeObjectForKey:@"asset"];
        self.progress = [aDecoder decodeFloatForKey:@"progress"];
        self.error = [aDecoder decodeObjectForKey:@"error"];
        self.hasFinished = [aDecoder decodeObjectForKey:@"hasFinished"];
        [self.data appendData:[aDecoder decodeObjectForKey:@"data"]];
    }
    return self;
}

-(instancetype)init {
    if (self = [super init]) {
        self.data = [NSMutableData new];
        self.progress = 0;
        self.hasFinished = NO;
    }
    return self;
}

-(NSUInteger)hash {
    return self.asset.hash;
}

-(BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]) {
        return NO;
    }
    return [self.asset isEqualToString:[object identifier]];
}


@end
