//
//  DrawerOverlayInternalProtocol.h
//  on-the-go
//
//  Created by Jimmy Ostoich on 11/12/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//


#import <Foundation/Foundation.h>

@protocol DrawerOverlayInternalProtocol <NSObject>
@required

@property (nonatomic, setter=setDrawerContainerInternal:) DrawerContainerViewController *drawerContainer;

@end
