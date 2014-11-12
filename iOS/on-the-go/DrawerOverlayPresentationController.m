//
//  DrawerOverlayPresentationController.m
//  on-the-go
//
//  Created by Jimmy Ostoich on 11/12/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//


#import "DrawerOverlayPresentationController.h"

@implementation DrawerOverlayPresentationController {
    UIView *_dimmingView;
    UITapGestureRecognizer *_chromeTapRecognizer;
}

-(instancetype)initWithPresentedViewController:(UIViewController *)presentedViewController presentingViewController:(UIViewController *)presentingViewController {
    
    _dimmingView = [UIView new];
    [_dimmingView setOpaque:YES];
    [_dimmingView setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.3]];
    
    _chromeTapRecognizer = [[UITapGestureRecognizer alloc] init];
    [_dimmingView addGestureRecognizer:_chromeTapRecognizer];
    
    return [super initWithPresentedViewController:presentedViewController presentingViewController:presentingViewController];
}

-(UITapGestureRecognizer *)chromeTapRecognizer {
    return _chromeTapRecognizer;
}

-(void)presentationTransitionWillBegin {
    UIView *containerView = [self containerView];
    UIViewController *presentedViewController = [self presentedViewController];
    
    [_dimmingView setFrame:[containerView bounds]];
    [_dimmingView setAlpha:0.0];
    
    [containerView insertSubview:_dimmingView atIndex:0];
    
    [[presentedViewController transitionCoordinator] animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [_dimmingView setAlpha:1.0];
        [self.presentingViewController.view setTintAdjustmentMode:UIViewTintAdjustmentModeDimmed];
        
        CIFilter *bnwFilter = [CIFilter filterWithName:@"CIMinimumComponent"];
        [bnwFilter setDefaults];
        [self.presentingViewController.view.layer setFilters:@[bnwFilter]];
    } completion:nil];
}

-(void)dismissalTransitionWillBegin {
    [[[self presentedViewController] transitionCoordinator] animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [_dimmingView setAlpha:0.0];
        [self.presentingViewController.view setTintAdjustmentMode:UIViewTintAdjustmentModeAutomatic];
    } completion:nil];
}

-(CGSize)sizeForChildContentContainer:(id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize {
    //make drawer a 3rd the width of its parent
    CGFloat height = CGRectGetHeight(UIScreen.mainScreen.bounds);
    return CGSizeMake(height <= 480 ? 220 : 240, parentSize.height);
}

-(CGRect)frameOfPresentedViewInContainerView {
    CGRect presentedViewFrame = CGRectZero;
    CGRect containerBounds = [self.containerView bounds];
    
    presentedViewFrame.size = [self sizeForChildContentContainer:(id<UIContentContainer>)self.presentedView withParentContainerSize:containerBounds.size];
    
    presentedViewFrame.origin.x = 0;
    
    return presentedViewFrame;
}

-(void)containerViewWillLayoutSubviews {
    [_dimmingView setBounds:self.containerView.bounds];
    [self.presentedView setFrame:[self frameOfPresentedViewInContainerView]];
}

@end
