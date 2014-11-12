//
//  DrawerContainerViewControler.m
//  on-the-go
//
//  Created by Jimmy Ostoich on 11/12/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "DrawerContainerViewController.h"
#import "DrawerOverlayInternalProtocol.h"
#import "DrawerOverlayViewController.h"
#import "DrawerOverlayPresentationController.h"
#import "DrawerOverlayAnimatedTransitioning.h"

#import <objc/runtime.h>

@import UIKit;

@interface UIViewController (DrawerInternal)

@property (nonatomic, weak) DrawerContainerViewController *drawerContainerViewController;

@end

@implementation DrawerContainerViewController {
    DrawerOverlayViewController *_overlayController;
    UINavigationController *_nav;
}

-(instancetype)initWithDrawerOverlay:(DrawerOverlayViewController *)overlayController {
    if (self == [super init]) {
        if (![overlayController isKindOfClass:[DrawerOverlayViewController class]]) {
            @throw [NSException exceptionWithName:@"Invalid Argument Exception" reason:@"Drawer Overlay View Controller of incompatible class" userInfo:nil];
        }
        
        _overlayController = overlayController;
        [_overlayController setDrawerContainerViewController:self];
        [(id<DrawerOverlayInternalProtocol>)_overlayController setDrawerContainerInternal:self];
    }
    
    return self;
}

-(void)loadView {
    self.view = [UIView new];
    [self.view setBackgroundColor:[UIColor whiteColor]];
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [_overlayController drawerContainerViewDidLoad];
}

-(void)setContentViewController:(UIViewController *)contentViewController {
    [self willChangeValueForKey:@"contentViewController"];
    _contentViewController = contentViewController;
    
    if (_contentViewController) {
        
        if (_nav == nil) {
            _nav = [[UINavigationController alloc] initWithRootViewController:_contentViewController];
            [self addChildViewController: _nav];
            _nav.view.frame = self.view.bounds;
            [_nav.view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
            [self.view addSubview: _nav.view];
            [_nav didMoveToParentViewController:self];
        } else {
            [_nav setViewControllers:@[_contentViewController] animated:NO];
        }
        
        [_contentViewController setDrawerContainerViewController:self];
        
        UIBarButtonItem *item = nil;
        UIImage *img = [_overlayController imageForOverlayBarButton];
        if (img) {
            item = [[UIBarButtonItem alloc] initWithImage:img style:UIBarButtonItemStylePlain target:self action:@selector(presentDrawer:)];
        }
        else {
            item = [[UIBarButtonItem alloc] initWithTitle:@"Menu" style:UIBarButtonItemStyleDone target:self action:@selector(presentDrawer:)];
        }
        
        [_contentViewController.navigationItem setLeftBarButtonItem:item];
    }
    
    
    [self didChangeValueForKey:@"contentViewController"];
}

-(void)closeDrawer {
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)presentDrawer:(id)sender {
    
    [_overlayController setTransitioningDelegate:(id<UIViewControllerTransitioningDelegate>)self];
    
    [self presentViewController:_overlayController animated:YES completion:nil];
}

-(void)chromeTapRecognizered:(UITapGestureRecognizer *)recognizer {
    [self closeDrawer];
}

#pragma mark UIViewControllerTransitioningDelegate

-(UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting sourceViewController:(UIViewController *)source {
    DrawerOverlayPresentationController *presenterController = [[DrawerOverlayPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
    
    [presenterController.chromeTapRecognizer addTarget:self action:@selector(chromeTapRecognizered:)];
    return presenterController;
}

-(id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    DrawerOverlayAnimatedTransitioning *animator = [DrawerOverlayAnimatedTransitioning new];
    animator.isPresentation = YES;
    return animator;
}

-(id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    DrawerOverlayAnimatedTransitioning *animator = [DrawerOverlayAnimatedTransitioning new];
    animator.isPresentation = NO;
    return animator;
}

@end

@implementation UIViewController (Drawer)

const void *DrawerContainerKey = "DrawerContainerKey";

@dynamic drawerContainerViewController;

-(DrawerContainerViewController *)drawerContainerViewController
{
    return (DrawerContainerViewController *)objc_getAssociatedObject(self, DrawerContainerKey);
}

-(void)setDrawerContainerViewController:(DrawerContainerViewController *)container
{
    objc_setAssociatedObject(self, DrawerContainerKey, container, OBJC_ASSOCIATION_ASSIGN);
}

@end
