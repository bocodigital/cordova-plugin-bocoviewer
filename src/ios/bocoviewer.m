/********* bocoviewer.m Cordova Plugin Implementation *******/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "bocoviewer.h"
#import <WebKit/WebKit.h>

@interface bocoviewer () <AVPlayerViewControllerDelegate> {
    // Member variables go here.
    AVPlayerViewController *controller;
    NSString *address;
    NSString *resourceId;
    NSString *mediaTitle;
    NSObject *timeObserveToken;
    NSTimer *timer;
    AVPlayer *player;
    BOOL isPaused;
    
    
    
}
@property (nonatomic, copy) NSString* callbackId;
@property (nonatomic, strong) UIWebView* webview;

- (void)ready:(CDVInvokedUrlCommand*)command;
- (void)showMedia:(CDVInvokedUrlCommand*)command;

@end

@implementation bocoviewer

- (void)ready:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* echo = [command.arguments objectAtIndex:0];
    
    if (echo != nil && [echo length] > 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:echo];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (BOOL)sendEventWithJSON:(id)JSON
{
    if ([JSON isKindOfClass:[NSDictionary class]]) {
        JSON = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:JSON options:0 error:NULL] encoding:NSUTF8StringEncoding];
    }
    NSString *script = [NSString stringWithFormat:@"cordova.fireWindowEvent('BOCOVIEWER.PROGRESSEVENT',%@);", JSON];
    NSString *result = [self stringByEvaluatingJavaScriptFromString:script];
    return [result length]? [result boolValue]: YES;
    
}

-(void)itemDidFinishPlaying:(NSNotification *) notification {
    // Will be called when AVPlayer finishes playing playerItem
    [self sendEventWithJSON:@{@"currentTime":@"complete"}];
    [timer invalidate];
    timer = nil;
}

- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script {
    __block NSString *result;
    if ([self.webView isKindOfClass:UIWebView.class]) {
        result = [(UIWebView *)self.webView stringByEvaluatingJavaScriptFromString:script];
    } else {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [((WKWebView *)self.webView) evaluateJavaScript:script completionHandler:^(id resultID, NSError *error) {
            result = [resultID description];
            dispatch_semaphore_signal(semaphore);
        }];
        
        // Ugly way to convert the async call into a sync call.
        // Since WKWebView calls back on the main thread we can't block.
        while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW)) {
            [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
        }
    }
    return result;
}

-(void)showMedia:(CDVInvokedUrlCommand *)command{
    
    self.webview = [[UIWebView alloc] init];
    
    NSString* urlString = [command.arguments objectAtIndex:0];
    
    self.callbackId = command.callbackId;
    
    NSURL *fileURL = [NSURL URLWithString:urlString];
    
    AVAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    AVPlayerItem *anItem = [AVPlayerItem playerItemWithAsset:asset];
    
    player = [AVPlayer playerWithPlayerItem:anItem];
    
    controller = [[AVPlayerViewController alloc] init];
    controller.player = player;
    controller.allowsPictureInPicturePlayback = YES;
    controller.showsPlaybackControls = YES;
    controller.delegate = self;
    [self.viewController presentViewController:controller animated:YES completion:^{
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:controller.player.currentItem];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:controller.player.currentItem];
        
        
    }];
    [player addObserver:self forKeyPath:@"rate" options:0 context:nil];
    [player seekToTime:kCMTimeZero];
    timer = [NSTimer scheduledTimerWithTimeInterval:1
                                             target:self
                                           selector:@selector(addBoundryTimeObserver)
                                           userInfo:nil
                                            repeats:YES];
    [player play];
    isPaused = NO;
    
    
}




-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    
    if ([keyPath isEqualToString:@"rate"]) {
        if (player.status == AVPlayerStatusReadyToPlay && player.rate == 0) {
            NSLog(@"Player is paused");
            isPaused = YES;
        } else if (player.status == AVPlayerStatusReadyToPlay && player.rate == 1) {
            // something went wrong. player.error should contain some information
            NSLog(@"Player is playing");
            isPaused = NO;
        }
    }
    
}

-(void)playerViewController:(AVPlayerViewController *)playerViewController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler{
    
    UIViewController *topController = [self topViewController];
    [topController presentViewController:playerViewController animated:YES completion:^{
        
        completionHandler(YES);
        
    }];
    
}

- (UIViewController *)topViewController{
    return [self topViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
}

- (UIViewController *)topViewController:(UIViewController *)rootViewController
{
    if (rootViewController.presentedViewController == nil) {
        return rootViewController;
    }
    
    if ([rootViewController.presentedViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)rootViewController.presentedViewController;
        UIViewController *lastViewController = [[navigationController viewControllers] lastObject];
        return [self topViewController:lastViewController];
    }
    
    UIViewController *presentedViewController = (UIViewController *)rootViewController.presentedViewController;
    return [self topViewController:presentedViewController];
}




- (void) addBoundryTimeObserver {
    CMTime current = controller.player.currentItem.currentTime;
    CMTime duration = controller.player.currentItem.duration;
    
    if (self.callbackId != nil) {
        NSString * cbid = [self.callbackId copy];
        self.callbackId = nil;
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event":@"timeEvent",@"duration":[NSNumber numberWithFloat:(CMTimeGetSeconds(duration))] }];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:cbid];
    }
    
    
    if(controller.player.rate == 0 && (controller.isBeingDismissed || controller.nextResponder == nil)){
        [timer invalidate];
        timer = nil;
    }
    
    [self sendEventWithJSON:@{@"currentTime":[NSNumber numberWithFloat:(CMTimeGetSeconds(current))]}];
    //NSLog(@"seconds = %f", CMTimeGetSeconds(current));
}

@end