//
//  DrawerOverlayAnimatedTransitioning.m
//  on-the-go
//
//  Created by Jimmy Ostoich on 11/12/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//


#import "DrawerOverlayAnimatedTransitioning.h"

@implementation DrawerOverlayAnimatedTransitioning


- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    return 0.5;
}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIView *fromView = [fromVC view];
    UIViewController *toVC   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *toView = [toVC view];
    
    UIView *containerView = [transitionContext containerView];
    
    BOOL isPresentation = [self isPresentation];
    
    if(isPresentation)
    {
        [containerView addSubview:toView];
    }
    
    UIViewController *animatingVC = isPresentation? toVC : fromVC;
    UIViewController *presenterVC = isPresentation? fromVC : toVC;
    UIView *animatingView = [animatingVC view];
    
    CGRect appearedFrame = [transitionContext finalFrameForViewController:animatingVC];
    CGRect dismissedFrame = appearedFrame;
    dismissedFrame.origin.x -= dismissedFrame.size.width;
    
    CGRect initialFrame = isPresentation ? dismissedFrame : appearedFrame;
    CGRect finalFrame = isPresentation ? appearedFrame : dismissedFrame;
    
    [animatingView setFrame:initialFrame];
    
    
    CGAffineTransform transform = isPresentation ? CGAffineTransformMakeScale(0.9, 0.9) : CGAffineTransformIdentity;
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext]
                          delay:0
         usingSpringWithDamping:1.0
          initialSpringVelocity:1.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         [animatingView setFrame:finalFrame];
                         [presenterVC.view setTransform:transform];
                     }
                     completion:^(BOOL finished){
                         if(![self isPresentation])
                         {
                             [fromView removeFromSuperview];
                         }
                         [transitionContext completeTransition:YES];
                     }];
}

@end
