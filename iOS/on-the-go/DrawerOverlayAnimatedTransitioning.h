//
//  DrawerOverlayAnimatedTransitioning.h
//  on-the-go
//
//  Created by Jimmy Ostoich on 11/12/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//


#import <Foundation/Foundation.h>
@import UIKit;

@interface DrawerOverlayAnimatedTransitioning : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, assign) BOOL isPresentation;
@end
