#import <Foundation/Foundation.h>


#import "MainViewController+RemoteEvents.h"

@implementation MainViewController (RemoteEvents)

- (void) remoteControlReceivedWithEvent: (UIEvent *) receivedEvent {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"remoteControlsEventNotification" object:receivedEvent];
}