//
//  DrawerOverlayViewController.h
//  on-the-go
//
//  Created by Jimmy Ostoich on 11/12/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DrawerContainerViewController.h"

@interface DrawerOverlayViewController : UIViewController

@property (nonatomic, readonly) DrawerContainerViewController *drawerContainer;

-(UIImage *)imageForOverlayBarButton;

-(void)drawerContainerViewDidLoad;


@end
