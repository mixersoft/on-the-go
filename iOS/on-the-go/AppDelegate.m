//
//  AppDelegate.m
//  on-the-go
//
//  Created by Jimmy Ostoich on 11/11/14.
//  Copyright (c) 2014 Jimmy Ostoich. All rights reserved.
//

#import "AppDelegate.h"
#import "DrawerContainerViewController.h"
#import "PhotosSource.h"
#import "PhotosUploader.h"
#import "CordovaNativeMessenger.h"

@interface AppDelegate () <PhotosUploaderDelegate, PHPhotoLibraryChangeObserver>
@property (nonatomic, copy) void (^sessionCompletionHandler)();
@property (nonatomic, weak) PhotosUploader *backgroundUploader;
@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    DrawerOverlayViewController *overlay = (DrawerOverlayViewController *)self.window.rootViewController;
    DrawerContainerViewController *container = [[DrawerContainerViewController alloc] initWithDrawerOverlay:overlay];
    [self.window setRootViewController:container];
    
    [[UINavigationBar appearance] setTranslucent:NO];
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:74/255.0 green:135/255.0 blue:238/255.0 alpha:1.0]];
    [[UINavigationBar appearance] setTintColor:[UIColor blackColor]];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            switch (status) {
                case PHAuthorizationStatusAuthorized: {
                    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:(id<PHPhotoLibraryChangeObserver>)self];
                    [CordovaNativeMessenger addResponseBlock:^(NSString *command, id data) {
                    }];
                    break;
                }
                case PHAuthorizationStatusRestricted:
                    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:(id<PHPhotoLibraryChangeObserver>)self];
                    break;
                case PHAuthorizationStatusDenied:
                    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:(id<PHPhotoLibraryChangeObserver>)self];
                    break;
                default:
                    break;
            }
            [[PhotosSource sharedInstance] invalidate];
        }];
    }];
    
    return YES;
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler {
    self.sessionCompletionHandler = completionHandler;
    self.backgroundUploader = [PhotosUploader uploaderWithSessionConfigurationIdentifier:identifier];
    [self.backgroundUploader addDelegate:(id<PhotosUploaderDelegate>)self];
}


#pragma mark PhotosUploaderDelegate

-(void)photoUploaderFinishedProcessingBackgroundEvents:(PhotosUploader *)uploader {
    if (self.sessionCompletionHandler) {
        self.sessionCompletionHandler();
    }
    self.sessionCompletionHandler = nil;
    [self.backgroundUploader removeDelegate:(id<PhotosUploaderDelegate>)self];
    self.backgroundUploader = nil;
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    [[PhotosSource sharedInstance] handleChange:changeInstance];
}

@end
