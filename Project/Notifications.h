//
//  Module: Notifications
//  Brightness
//
//  Created by Florian on 04/09/15.
//
//  Allows to show notifications in the top-right corner of the screen, passing as the Finder.
//
#import "Brightness.h"

/** Use by this implementation, do not instantiate. */
@interface NotificationCenterDelegate : NSObject<NSUserNotificationCenterDelegate>
@property (nonatomic, assign) BOOL keepRunning;
@end

/** Public notification API */
void SetupForNotifications();		// Run first in order to show notifications; the app needs live long enough for the duration of the notification
void ShowNotification(BrightnessParams *params, BOOL willKeepOpen, BOOL didTouchBrightness);
void ShowNotificationMessage(const char *title, const char *text, const char *informativeText);
