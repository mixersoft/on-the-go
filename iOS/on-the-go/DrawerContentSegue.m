//
//  DrawerContentSegue.m
//  on-the-go
//
//  Created by Dimitar Ostoich on 11/12/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.

#import "DrawerContentSegue.h"
#import "DrawerOverlayViewController.h"

@implementation DrawerContentSegue

-(DrawerContainerViewController *)container
{
    if ([self.sourceViewController isKindOfClass:DrawerOverlayViewController.class])
        return [(DrawerOverlayViewController *)self.sourceViewController drawerContainer];
    
    DrawerContainerViewController *container = [self.sourceViewController drawerContainerViewController];

    if (container == nil) {
        @throw [NSException exceptionWithName:@"Wrong Class Exception!" reason:@"View Controller must be a subclass of DrawerOverlayViewController or has an associated drawerContainer reference." userInfo:nil];
    }
    
    return container;
}

- (void)perform {
    
    [self.container setContentViewController:self.destinationViewController];
    if (!self.keepDrawerOpen.boolValue) {
        [self.container closeDrawer];
    }
}

@end
