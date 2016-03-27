#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "Notifications.h"

NSString *fakeBundleIdentifier = nil;

@implementation NSBundle(swizle)

// Overriding bundleIdentifier works, but overriding NSUserNotificationAlertStyle does not work.
- (NSString *)__bundleIdentifier {
	if (self == [NSBundle mainBundle]) {
		return fakeBundleIdentifier ? fakeBundleIdentifier : @"com.apple.finder";
	} else {
		return [self __bundleIdentifier];
	}
}

@end

static BOOL InstallNSBundleHook() {
	Class class = objc_getClass("NSBundle");
	if (class) {
		method_exchangeImplementations(class_getInstanceMethod(class, @selector(bundleIdentifier)),
									   class_getInstanceMethod(class, @selector(__bundleIdentifier)));
		return YES;
	}
	return NO;
}


#pragma mark - NotificationCenterDelegate

@implementation NotificationCenterDelegate

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification {
	self.keepRunning = NO;
}

@end

void SetupForNotifications() {
	if (InstallNSBundleHook()) {
		fakeBundleIdentifier = @"com.apple.finder";
	}
}

void ShowNotification(BrightnessParams *params, BOOL willKeepOpen, BOOL didTouchBrightness) {
#define APPEND(t) if (text[0]) strcat(text, t)
	char text[256], temp[256];
	strcpy(text, "");

	if (didTouchBrightness) {
		sprintf(temp, "%d%%", params->brightness);
		strcat(text, temp);
	}
	if (fabsf(params->temperature - 6500) >= FLT_EPSILON) {
		APPEND(", ");
		sprintf(temp, "%dK", (int)params->temperature);
		strcat(text, temp);
	}
	if (fabsf(params->gamma - 1) >= FLT_EPSILON) {
		APPEND(", ");
		sprintf(temp, "Ɣ: %.2f", params->gamma);
		strcat(text, temp);
	}
	if (fabsf(params->addition) >= FLT_EPSILON) {
		APPEND(", ");
		sprintf(temp, "black: %+d%%", (int)(params->addition * 100.0f));
		strcat(text, temp);
	}
	if (willKeepOpen) {
		APPEND(" ");
		strcat(text, "(app needs keep running).");
	}
	if (!text[0])
		strcpy(text, "Nothing done. Type brightness --help if needed.");
	
	ShowNotificationMessage("Brightness", text, NULL);
#undef APPEND_NEWLINE
}

void ShowNotificationMessage(const char *title, const char *text, const char *informativeText) {
	NSUserNotificationCenter *nc = [NSUserNotificationCenter defaultUserNotificationCenter];
	NotificationCenterDelegate *ncDelegate = [[NotificationCenterDelegate alloc] init];
	ncDelegate.keepRunning = YES;
	nc.delegate = ncDelegate;
	
	/*	NSUserNotification *notification = [[NSUserNotification alloc] init];
	 [notification setTitle:@"Hello World"];
	 [notification setInformativeText:@"Hello world message"];
	 [notification setDeliveryDate:[NSDate dateWithTimeInterval:20 sinceDate:[NSDate date]]];
	 [notification setSoundName:NSUserNotificationDefaultSoundName];
	 NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
	 [center scheduleNotification:notification];*/
	
	NSUserNotification *note = [[NSUserNotification alloc] init];
	note.title = [NSString stringWithCString:title encoding:NSUTF8StringEncoding];
	note.subtitle = [NSString stringWithCString:text encoding:NSUTF8StringEncoding];
	if (informativeText)
		note.informativeText = [NSString stringWithCString:informativeText encoding:NSUTF8StringEncoding];
	
	[nc deliverNotification:note];
	while (ncDelegate.keepRunning) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	}
}
