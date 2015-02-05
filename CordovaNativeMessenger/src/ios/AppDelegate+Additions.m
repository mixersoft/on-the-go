//
//  AppDelegate+Additions.m
//  On-the-Go
//
//  Created by Dimitar Ostoich on 2/5/15.
//
//

#import "AppDelegate+Additions.h"
#import "PhotosUploader.h"
#import <objc/runtime.h>

@interface AppDelegate ()

@property (nonatomic, copy) void (^sessionCompletionHandler)();
@property (nonatomic, assign) PhotosUploader *backgroundUploader;

@end

@implementation AppDelegate (Additions)

-(void)setSessionCompletionHandler:(void (^)())sessionCompletionHandler {
    objc_setAssociatedObject(self, @selector(sessionCompletionHandler), sessionCompletionHandler, OBJC_ASSOCIATION_COPY);
}

-(void (^)())sessionCompletionHandler {
    return objc_getAssociatedObject(self, _cmd);
}

-(void)setBackgroundUploader:(PhotosUploader *)backgroundUploader {
    objc_setAssociatedObject(self, @selector(backgroundUploader), backgroundUploader, OBJC_ASSOCIATION_ASSIGN);
}

-(PhotosUploader *)backgroundUploader {
    return objc_getAssociatedObject(self, _cmd);
}

+(void)swizzleSelector:(SEL)selector1 withSelector:(SEL)selector2 {
    Class class = [self class];
    Method originalMethod = class_getInstanceMethod(class, selector1);
    Method swizzledMethod = class_getInstanceMethod(class, selector2);
    
    BOOL didAddMethod =
    class_addMethod(class,
                    selector1,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                            selector2,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        
        SEL originalSelector = @selector(application:handleEventsForBackgroundURLSession:completionHandler:);
        SEL swizzledSelector = @selector(xxx_application:handleEventsForBackgroundURLSession:completionHandler:);
        [self swizzleSelector:originalSelector withSelector:swizzledSelector];
        
    });
}

#pragma mark - Method Swizzling

- (void)xxx_application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler {
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

@end
