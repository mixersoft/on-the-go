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
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeFloat:self.progress forKey:@"progress"];
    [aCoder encodeObject:self.error forKey:@"error"];
    [aCoder encodeObject:self.data forKey:@"data"];
    
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [self init]) {
        self.identifier = [aDecoder decodeObjectForKey:@"identifier"];
        self.progress = [aDecoder decodeFloatForKey:@"progress"];
        self.error = [aDecoder decodeObjectForKey:@"error"];
        [self.data appendData:[aDecoder decodeObjectForKey:@"data"]];
    }
    return self;
}

-(instancetype)init {
    if (self = [super init]) {
        self.data = [NSMutableData new];
    }
    return self;
}

-(NSUInteger)hash {
    return self.identifier.hash;
}

-(BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]) {
        return NO;
    }
    return [self.identifier isEqualToString:[object identifier]];
}

@end
