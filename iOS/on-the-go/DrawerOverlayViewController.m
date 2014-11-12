//
//  DrawerOverlayViewController.m
//  on-the-go
//
//  Created by Jimmy Ostoich on 11/12/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "DrawerOverlayViewController.h"
#import "DrawerOverlayInternalProtocol.h"

@interface DrawerOverlayViewController () <DrawerOverlayInternalProtocol>

@end

@implementation DrawerOverlayViewController {
    __weak DrawerContainerViewController *_containerController;
}

-(void)setDrawerContainerInternal:(DrawerContainerViewController *)container {
    [self willChangeValueForKey:@"drawerContainer"];
    _containerController = container;
    [self didChangeValueForKey:@"drawerContainer"];
}

-(DrawerContainerViewController *)drawerContainer {
    return _containerController;
}

-(UIImage *)imageForOverlayBarButton {
    return nil;
}

-(void)drawerContainerViewDidLoad {
    
}

-(void)setModalPresentationStyle:(UIModalPresentationStyle)modalPresentationStyle {
    [super setModalPresentationStyle:UIModalPresentationCustom];
}

-(UIModalPresentationStyle)modalPresentationStyle {
    return UIModalPresentationCustom;
}

@end
