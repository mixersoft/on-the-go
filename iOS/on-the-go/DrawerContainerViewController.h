//
//  DrawerContainerViewControler.h
//  on-the-go
//
//  Created by Jimmy Ostoich on 11/12/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DrawerOverlayViewController;

@interface DrawerContainerViewController : UIViewController

@property (nonatomic, readonly) DrawerOverlayViewController *overlayController;

@property (nonatomic, strong) UIViewController *contentViewController;

-(instancetype)initWithDrawerOverlay:(DrawerOverlayViewController *)overlayController;

-(void)closeDrawer;

@end

@interface UIViewController (Drawer)

@property (nonatomic, readonly) DrawerContainerViewController *drawerContainerViewController;

@end
