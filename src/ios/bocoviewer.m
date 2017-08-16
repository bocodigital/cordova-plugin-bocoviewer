/********* bocoviewer.m Cordova Plugin Implementation *******/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "bocoviewer.h"
#import <WebKit/WebKit.h>
#import <MediaPlayer/MediaPlayer.h>

@interface bocoviewer () <AVPlayerViewControllerDelegate,AVAudioPlayerDelegate> {
    // Member variables go here.
    AVPlayerViewController *controller;
    AVAudioPlayer *audioPlayer;
    AVURLAsset* audioAsset;
    NSString *address;
    NSString *resourceId;
    NSString *mediaTitle;
    NSObject *timeObserveToken;
    NSTimer *timer;
    NSTimer *updateTimer;
    AVPlayer *player;
    BOOL isPaused;
    UIToolbar *toolBar;
    UIBarButtonItem *pauseButton;
    UIBarButtonItem *playButton;
    UIBarButtonItem *flexSpace;
    UIBarButtonItem *closeButton;
    UIBarButtonItem *volumeButton;
    UISlider *slider;
    UISlider *volumeSlider;
    UILabel *currentTimeLabel;
    UILabel *durationTimeLabel;
    UILabel *mediaTitleLabel;
    float currentVolume;
    BOOL isMuted;
    
    
}
@property (nonatomic, copy) NSString* callbackId;
@property (nonatomic, strong) UIWebView* webview;
@property (retain) UIView* audioPlayerView;

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

-(void)pauseAudio{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
    
    if(isPaused){
        [audioPlayer play];
        isPaused = NO;
        pauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(pauseAudio)];
        
        UIColor *grey =[UIColor colorWithRed:227.0 green:227.0 blue:227.0 alpha:1];
        [pauseButton setTintColor:grey];
        
        [toolbarItems replaceObjectAtIndex:0 withObject:pauseButton];
        toolBar.items = toolbarItems;
    }else{
        [audioPlayer pause];
        isPaused = YES;
        playButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(pauseAudio)];
        
        UIColor *grey =[UIColor colorWithRed:227.0 green:227.0 blue:227.0 alpha:1];
        [playButton setTintColor:grey];
        
        [toolbarItems replaceObjectAtIndex:0 withObject:playButton];
        toolBar.items = toolbarItems;
    }
}

- (void)updateSeekBar{
    float progress = audioPlayer.currentTime;
    [slider setValue:progress];
    NSTimeInterval theTimeInterval = audioPlayer.currentTime;
    
    CMTime currentTime = CMTimeMakeWithSeconds(theTimeInterval, 1000000);
    // Get the system calendar
    NSCalendar *sysCalendar = [NSCalendar currentCalendar];
    
    // Create the NSDates
    NSDate *date1 = [[NSDate alloc] init];
    NSDate *date2 = [[NSDate alloc] initWithTimeInterval:theTimeInterval sinceDate:date1];
    // Get conversion to hours, minutes, seconds
    unsigned int unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *breakdownInfo = [sysCalendar components:unitFlags fromDate:date1  toDate:date2  options:0];
    currentTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)[breakdownInfo hour], (long)[breakdownInfo minute], (long)[breakdownInfo second]];

    [self sendEventWithJSON:@{@"currentTime":[NSNumber numberWithFloat:CMTimeGetSeconds(currentTime)]}];
}

-(void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    
    [audioPlayer stop];
    
    CGRect newFrame = CGRectMake(0, self.viewController.view.frame.size.height, self.viewController.view.frame.size.width, 40);
    
    [UIView animateWithDuration:0.5
                          delay:0.5
                        options: UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.audioPlayerView.frame = newFrame;
                     }
                     completion:^(BOOL finished){
                         [self.audioPlayerView removeFromSuperview];
                         [self sendEventWithJSON:@{@"currentTime":@"complete"}];
                         [updateTimer invalidate];
                         updateTimer = nil;
                     }];
    
}

-(void)muteAudio:(id)sender{
    
    UIColor *grey =[UIColor colorWithRed:227.0 green:227.0 blue:227.0 alpha:1];
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
    
    if(isMuted){
        volumeButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Volume"] style:UIBarButtonItemStylePlain target:self action:@selector(muteAudio:)];
        [volumeButton setTintColor:grey];
        
        [toolbarItems replaceObjectAtIndex:10 withObject:volumeButton];
        toolBar.items = toolbarItems;
        
        audioPlayer.volume = currentVolume;
        isMuted = NO;
    }else{
        volumeButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Mute"] style:UIBarButtonItemStylePlain target:self action:@selector(muteAudio:)];
        [volumeButton setTintColor:grey];
        
        [toolbarItems replaceObjectAtIndex:10 withObject:volumeButton];
        toolBar.items = toolbarItems;
        
        currentVolume = audioPlayer.volume;
        
        
        audioPlayer.volume = 0;
        isMuted = YES;
    }
    
}

-(void)closeAudio:(id)sender{
    
    [audioPlayer stop];
    
    CGRect newFrame = CGRectMake(0, self.viewController.view.frame.size.height, self.viewController.view.frame.size.width, 40);
    
    [UIView animateWithDuration:0.5
                          delay:0.5
                        options: UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.audioPlayerView.frame = newFrame;
                     }
                     completion:^(BOOL finished){
                         if([self.audioPlayerView isDescendantOfView:self.viewController.view]){
                             [toolBar removeFromSuperview];
                             [self.audioPlayerView removeFromSuperview];
                             self.audioPlayerView = nil;
                            [updateTimer invalidate];
                            updateTimer = nil;
                             
                         }
                         
                     }];
    
}

-(void)seekTime:(id)sender {
    
    audioPlayer.currentTime = slider.value;
    
}


// Process remote control events
- (void) remoteControlReceivedWithEvent:(NSNotification *) notification {
    
     UIEvent * receivedEvent = notification.object;
    
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) {
                case UIEventSubtypeRemoteControlTogglePlayPause:
                [self pauseAudio];
                break;
                case UIEventSubtypeRemoteControlPause:
                [self pauseAudio];
                break;
                case UIEventSubtypeRemoteControlStop:
                [self pauseAudio];
                break;
                case UIEventSubtypeRemoteControlPlay:
                [self pauseAudio];
                break;
            default:
                break;
        }
    }
}

-(void)playNewAudio:(CDVInvokedUrlCommand *)command{
    [audioPlayer stop];
    
    CGRect newFrame = CGRectMake(0, self.viewController.view.frame.size.height, self.viewController.view.frame.size.width, 40);
    
    [UIView animateWithDuration:0.5
                          delay:0.5
                        options: UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.audioPlayerView.frame = newFrame;
                     }
                     completion:^(BOOL finished){
                         if([self.audioPlayerView isDescendantOfView:self.viewController.view]){
                             [toolBar removeFromSuperview];
                             [self.audioPlayerView removeFromSuperview];
                             self.audioPlayerView = nil;
                             [self playAudio:command];
                         }
                         
                     }];
    
}

-(void)playAudio:(CDVInvokedUrlCommand *)command{
    
    if(self.audioPlayerView != nil){
        [self playNewAudio:command];
        return;
    }
    
    NSDictionary* options = [command.arguments objectAtIndex:0];
    
    NSString* urlString = options[@"url"];
    
    isMuted = NO;
    
    currentTimeLabel = [[UILabel alloc] init];
    currentTimeLabel.textColor = [UIColor darkGrayColor];
    
    durationTimeLabel = [[UILabel alloc] init];
    durationTimeLabel.textColor = [UIColor darkGrayColor];
    
    mediaTitleLabel = [[UILabel alloc] init];
    mediaTitleLabel.textColor = [UIColor whiteColor];
    [mediaTitleLabel setPreferredMaxLayoutWidth:80];
    
    NSURL *fileURL = [NSURL URLWithString:urlString];
    
    self.audioPlayerView = [[UIView alloc] initWithFrame:CGRectMake(0, self.viewController.view.frame.size.height, self.viewController.view.frame.size.width, 40)];
    
    self.audioPlayerView.layer.backgroundColor = [UIColor blackColor].CGColor;
    
    mediaTitle =  [[fileURL absoluteString] lastPathComponent];
    
    toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 5, self.viewController.view.frame.size.width, 30)];
    [toolBar setBarStyle:UIBarStyleBlackTranslucent];
    pauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(pauseAudio)];
    UIColor *grey =[UIColor colorWithRed:227.0 green:227.0 blue:227.0 alpha:1];
    [pauseButton setTintColor:grey];
    pauseButton.width = 10;
    
    volumeButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Volume"] style:UIBarButtonItemStylePlain target:self action:@selector(muteAudio:)];
    
    [volumeButton setTintColor:grey];
    
    closeButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Close"] style:UIBarButtonItemStylePlain target:self action:@selector(closeAudio:)];
    
    [closeButton setTintColor:grey];
    
    flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    
    slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 630, 30)];
    
    [slider setThumbImage:[[UIImage alloc] init] forState:UIControlStateNormal];
    
    [slider addTarget:self
               action:@selector(seekTime:)
     forControlEvents:UIControlEventValueChanged];
    
    [slider setTintColor:[UIColor whiteColor]];
    
    //volumeSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 700, 30)];
    
    UIBarButtonItem *sliderAsToolbarItem = [[UIBarButtonItem alloc] initWithCustomView:slider];
    // Set the width of aSlider
    [sliderAsToolbarItem setWidth:700];
    
    UIBarButtonItem *currentTimeToolBarItem = [[UIBarButtonItem alloc] initWithCustomView:currentTimeLabel];
    currentTimeToolBarItem.width = 200;
    
    UIBarButtonItem *durationTimeToolBarItem = [[UIBarButtonItem alloc] initWithCustomView:durationTimeLabel];
    durationTimeToolBarItem.width = 200;
    
    UIBarButtonItem *mediaTitleToolBarItem = [[UIBarButtonItem alloc] initWithCustomView:mediaTitleLabel];
    mediaTitleToolBarItem.width = 200;
    
    mediaTitleLabel.text = mediaTitle;
    
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
    [toolbarItems addObject:pauseButton];
    [toolbarItems addObject:flexSpace];
    [toolbarItems addObject:mediaTitleToolBarItem];
    [toolbarItems addObject:flexSpace];
    [toolbarItems addObject:currentTimeToolBarItem];
    [toolbarItems addObject:flexSpace];
    [toolbarItems addObject:sliderAsToolbarItem];
    [toolbarItems addObject:flexSpace];
    [toolbarItems addObject:durationTimeToolBarItem];
    [toolbarItems addObject:flexSpace];
    [toolbarItems addObject:volumeButton];
    [toolbarItems addObject:flexSpace];
    [toolbarItems addObject:closeButton];
    toolBar.items = toolbarItems;
    
    [self.audioPlayerView addSubview:toolBar];
    
    
    audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:nil];
    
    audioPlayer.delegate = self;
    
    
    [slider setMinimumValue:0.0];
    [slider setMaximumValue:audioPlayer.duration];
    
    NSTimeInterval theTimeInterval = audioPlayer.currentTime;
    NSTimeInterval theDurationTimeInterval = audioPlayer.duration;
    // Get the system calendar
    NSCalendar *sysCalendar = [NSCalendar currentCalendar];
    
    // Create the NSDates
    NSDate *date1 = [[NSDate alloc] init];
    NSDate *date2 = [[NSDate alloc] initWithTimeInterval:theTimeInterval sinceDate:date1];
    // Get conversion to hours, minutes, seconds
    unsigned int unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *breakdownInfo = [sysCalendar components:unitFlags fromDate:date1  toDate:date2  options:0];
    currentTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)[breakdownInfo hour], (long)[breakdownInfo minute], (long)[breakdownInfo second]];
    
    NSDate *ddate1 = [[NSDate alloc] init];
    NSDate *ddate2 = [[NSDate alloc] initWithTimeInterval:theDurationTimeInterval sinceDate:date1];
    // Get conversion to hours, minutes, seconds
    unsigned int unitFlagsD = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *breakdownInfoD = [sysCalendar components:unitFlagsD fromDate:ddate1  toDate:ddate2  options:0];
    durationTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)[breakdownInfoD hour], (long)[breakdownInfoD minute], (long)[breakdownInfoD second]];
    
    [currentTimeLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:10]];
    [durationTimeLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:10]];
    [mediaTitleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:10]];
    
    
    if (self.callbackId != nil) {
        NSString * cbid = [self.callbackId copy];
        self.callbackId = nil;
        audioAsset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
        CMTime seekingCM = audioAsset.duration;
        
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event":@"timeEvent",@"duration":[NSNumber numberWithFloat:(CMTimeGetSeconds(seekingCM))] }];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:cbid];
    }
    
    
    
    
    
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateSeekBar) userInfo:nil repeats:YES];
    
    [self.viewController.view addSubview:self.audioPlayerView];
    
   [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(remoteControlReceivedWithEvent:) name:@"remoteControlsEventNotification" object:nil];


    
    NSDictionary *info = @{ MPMediaItemPropertyArtist: mediaTitle,
                            MPMediaItemPropertyAlbumTitle: mediaTitle,
                            MPMediaItemPropertyTitle: mediaTitle };
    
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    [commandCenter.changePlaybackPositionCommand setEnabled:true];
    [commandCenter.nextTrackCommand setEnabled:false];
    [commandCenter.previousTrackCommand setEnabled:false];
    [commandCenter.seekForwardCommand setEnabled:false];
    [commandCenter.skipForwardCommand setEnabled:false];
    [commandCenter.skipBackwardCommand setEnabled:false];

    [audioPlayer play];
    
    CGRect newFrame = CGRectMake(0, self.viewController.view.frame.size.height -40, self.viewController.view.frame.size.width, 40);
    
    
    [UIView animateWithDuration:0.5
                          delay:0.5
                        options: UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.audioPlayerView.frame = newFrame;
                     }
                     completion:^(BOOL finished){
                         NSLog(@"Done!");
                     }];
    
}

-(void)showMedia:(CDVInvokedUrlCommand *)command{
    
    self.webview = [[UIWebView alloc] init];
    
    NSDictionary* options = [command.arguments objectAtIndex:0];
    
    NSString* urlString = options[@"url"];
    
    self.callbackId = command.callbackId;
    
    if([urlString rangeOfString:@"mp3"].location != NSNotFound){
        
        [self playAudio:command];
        return;
        
    }
    
    NSString* embedded = options[@"embedded"];
    
    
    
    NSURL *fileURL = [NSURL URLWithString:urlString];
    
    
    
    AVAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    AVPlayerItem *anItem = [AVPlayerItem playerItemWithAsset:asset];
    
    player = [AVPlayer playerWithPlayerItem:anItem];
    
    
    controller = [[AVPlayerViewController alloc] init];
    controller.player = player;
    controller.allowsPictureInPicturePlayback = YES;
    controller.showsPlaybackControls = YES;
    controller.delegate = self;
    
    if(embedded != nil && [embedded isEqualToString:@"true"]){
        CGRect rect = CGRectMake([options[@"x"] integerValue], [options[@"y"] integerValue], [options[@"width"] integerValue], [options[@"height"] integerValue]);
        
        [controller.view setFrame:rect];
        [self.viewController.view addSubview:controller.view];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:controller.player.currentItem];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:controller.player.currentItem];
    }else{
        [self.viewController presentViewController:controller animated:YES completion:^{
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:controller.player.currentItem];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:controller.player.currentItem];
        }];
    }
    
    
    
    
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


-(void)closeViewer:(CDVInvokedUrlCommand *)command{
    [controller.view removeFromSuperview];
    if(self.audioPlayerView != nil){
        [audioPlayer stop];
        [self.audioPlayerView removeFromSuperview];
    }
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


