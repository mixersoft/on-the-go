//
//  UIImageView+Additions.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/18/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "UIImageView+Additions.h"
#import <objc/runtime.h>

@implementation UIImageView (Additions)


-(void)setImageURL:(NSURL *)imageURL {
    objc_setAssociatedObject(self, @selector(imageURL), imageURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setImage:nil];
    if (!imageURL)
        return;
    
    __weak UIImageView *_self = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
        UIImage *image = [UIImage imageWithData:imageData];
        dispatch_async(dispatch_get_main_queue(), ^{
            [_self setImage:image];
        });
    });
}

-(NSURL *)imageURL {
    return objc_getAssociatedObject(self, _cmd);
}

@end
