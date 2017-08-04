/********* bocoviewer.m Cordova Plugin Implementation *******/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "bocoviewer.h"
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>

@interface bocoviewer () <AVPlayerViewControllerDelegate, AVPictureInPictureControllerDelegate> {
    // Member variables go here.
    AVPlayerViewController *controller;
    AVPictureInPictureController *pinp;
    NSString *address;
    NSString *resourceId;
    NSString *mediaTitle;
    NSObject *timeObserveToken;
    NSTimer *timer;
    AVPlayer *player;
    AVPlayerLayer *playerLayer;
    UIToolbar *toolBar;
    UIBarButtonItem *pauseButton;
    UIBarButtonItem *playButton;
    UIBarButtonItem *pictureInPictureButton;
    UIBarButtonItem *flexSpace;
    UIBarButtonItem *closeButton;
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

-(void)pauseVideo{
    
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
    
    if(isPaused){
        [player play];
        pauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(pauseVideo)];
        
        UIColor *grey =[UIColor colorWithRed:227.0 green:227.0 blue:227.0 alpha:1];
        [pauseButton setTintColor:grey];
        
        [toolbarItems replaceObjectAtIndex:0 withObject:pauseButton];
        toolBar.items = toolbarItems;
    }else{
        [player pause];
        playButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(pauseVideo)];
        
        UIColor *grey =[UIColor colorWithRed:227.0 green:227.0 blue:227.0 alpha:1];
        [playButton setTintColor:grey];
        
        [toolbarItems replaceObjectAtIndex:0 withObject:playButton];
        toolBar.items = toolbarItems;
    }
    
    
    
    
    
}

-(void)openPictureInPicture{
    [toolBar removeFromSuperview];
    [pinp startPictureInPicture];
    
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
    [controller.view setFrame:CGRectMake(408, 212, 613, 420)];
    controller.player = player;
    controller.allowsPictureInPicturePlayback = YES;
    controller.showsPlaybackControls = YES;
    controller.delegate = self;
    [self.viewController.view addSubview:controller.view];
    //[self.viewController presentViewController:controller animated:YES completion:^{
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:controller.player.currentItem];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:controller.player.currentItem];
        
        
    //}];
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



-(void)showMediaEmbedded:(CDVInvokedUrlCommand *)command{
    
    self.webview = [[UIWebView alloc] init];
    
    NSString* urlString = [command.arguments objectAtIndex:0];
    
    self.callbackId = command.callbackId;
    
    NSURL *fileURL = [NSURL URLWithString:urlString];
    
    AVAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    AVPlayerItem *anItem = [AVPlayerItem playerItemWithAsset:asset];
    
    player = [AVPlayer playerWithPlayerItem:anItem];

    
    playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    [playerLayer setFrame:CGRectMake(408, 212, 613, 420)];
    
    [playerLayer setVideoGravity:AVLayerVideoGravityResize];
    
    
    
    toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(playerLayer.frame.origin.x +10, playerLayer.frame.origin.y + playerLayer.bounds.size.height -40, playerLayer.bounds.size.width-20, 30)];
    toolBar.layer.cornerRadius = 12.0;
    toolBar.layer.borderColor = [UIColor darkGrayColor].CGColor;
    toolBar.layer.borderWidth = 0.5;
    toolBar.clipsToBounds = YES;

    [toolBar setBarStyle:UIBarStyleBlackTranslucent];
    pauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(pauseVideo)];
    UIColor *grey =[UIColor colorWithRed:227.0 green:227.0 blue:227.0 alpha:1];
    [pauseButton setTintColor:grey];
    pauseButton.width = 10;
    
    UIImage *pinpButtonImage = [AVPictureInPictureController pictureInPictureButtonStartImageCompatibleWithTraitCollection:nil];
    
    pictureInPictureButton = [[UIBarButtonItem alloc] initWithImage:pinpButtonImage style:UIBarButtonItemStylePlain target:self action:@selector(openPictureInPicture)];
    [pictureInPictureButton setTintColor:grey];
    
    flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    flexSpace.width = 100;
    
    
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
    [toolbarItems addObject:pauseButton];
    [toolbarItems addObject:flexSpace];
    [toolbarItems addObject:pictureInPictureButton];
    toolBar.items = toolbarItems;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:playerLayer.player.currentItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:playerLayer.player.currentItem];
    
    

    [self.viewController.view.layer addSublayer:playerLayer];
    [self.viewController.view addSubview:toolBar];
    [player addObserver:self forKeyPath:@"rate" options:0 context:nil];
    [player seekToTime:kCMTimeZero];
    timer = [NSTimer scheduledTimerWithTimeInterval:1
                                             target:self
                                           selector:@selector(addBoundryTimeObserver)
                                           userInfo:nil
                                            repeats:YES];
    [player play];
    [self setupSuport];
    isPaused = NO;
    
    
}

-(void)setupSuport
{
    if([AVPictureInPictureController isPictureInPictureSupported])
    {
        
        pinp =  [[AVPictureInPictureController alloc] initWithPlayerLayer:playerLayer];
        pinp.delegate = self;
        
    }
    else
    {
        // not supported PIP start button desable here
    }
    
}


-(void)closeViewer:(CDVInvokedUrlCommand *)command{
    [toolBar removeFromSuperview];
    [playerLayer removeFromSuperlayer];
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

-(void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController{
    
    [playerLayer removeFromSuperlayer];
}

-(void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler{
    
    UIViewController *topController = [self topViewController];
    [topController.view.layer addSublayer:playerLayer];
    [topController.view addSubview:toolBar];
    
    completionHandler(YES);
    
    
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
    CMTime current = playerLayer.player.currentItem.currentTime;
    CMTime duration = playerLayer.player.currentItem.duration;
    
    if (self.callbackId != nil) {
        NSString * cbid = [self.callbackId copy];
        self.callbackId = nil;
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event":@"timeEvent",@"duration":[NSNumber numberWithFloat:(CMTimeGetSeconds(duration))] }];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:cbid];
    }
    
    
    if(playerLayer.player.rate == 0 && (self.viewController.isBeingDismissed || self.viewController.nextResponder == nil)){
        [timer invalidate];
        timer = nil;
        
    }
    
    [self sendEventWithJSON:@{@"currentTime":[NSNumber numberWithFloat:(CMTimeGetSeconds(current))]}];
    //NSLog(@"seconds = %f", CMTimeGetSeconds(current));
}

@end

