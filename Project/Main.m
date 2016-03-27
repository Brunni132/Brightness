#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#import "Brightness.h"
#import "Notifications.h"

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
int main(int argc, char *argv[]) {
	BOOL touchesBrightness = NO, wantNotifications = YES, showHelp = NO;
	BOOL saveConfig = YES;
	BrightnessParams params;
	getCurrentBrightnessFromFile(&params);
	
	// Argument parsing
	for (int i = 1; i < argc; i++) {
		if (!strncmp(argv[i], "--sil", 5))
			wantNotifications = NO;
		else if (!strncmp(argv[i], "--nos", 5))
			saveConfig = NO;
		else if (!strncmp(argv[i], "--hel", 5))
			showHelp = YES;
		else if (!strncmp(argv[i], "--def", 5))
			initBrightnessParams(&params);
		else if (argv[i][0] == 'g')
			params.gamma = atof(argv[i] + 1);
		else if (argv[i][0] == 'b')
			params.addition = atof(argv[i] + 1) / 100.0f;
		else if (argv[i][0] == 't')
			params.temperature = atof(argv[i] + 1);
		else if (argv[i][0] == 'd')
			params.delayUs = (uint32_t) (atof(argv[i] + 1) * 1000000.f);
		else if (argv[i][0] == '+' || argv[i][0] == '-')
			params.brightness += atoi(argv[i]), touchesBrightness = YES;
		else if (argv[i][0] >= '0' && argv[i][0] <= '9')
			params.brightness = atoi(argv[i]), touchesBrightness = YES;
		else
			printf("Unrecognized option %c, aborting\n", argv[i][0]), showHelp = YES;
	}
		
	if (showHelp) {
		printf("Usage: brightness +5 g1.0 a0.0 t6500 d30 --silent\n"
			   "Configures the brightness of non-Apple external displays and other goodies. All\n"
			   "    arguments are optional.\n"
			   "--default: starts with default parameters instead of previously saved ones.\n"
			   "   Takes effect from the point where located on the command line, so you should\n"
			   "   come as the first option.\n"
			   "(number): allows to increase or decrease the current brightness relatively to\n"
			   "   the previous value. You may for instance pass -5 (reduce brightness of 5%%),\n"
			   "   +10 or 50 (set to 50%%). Passing less than zero darkens the display in\n"
			   "   software. Keep between -80 and 100.\n"
			   "g: sets the gamma correction. Default is 1.0 (same as mapped by your\n"
			   "   manufacturer); bigger number appears clearer and can be easier to the eyes,\n"
			   "   while smaller number appears darker, more vivid.\n"
			   "b: sets the black level (0 ~ 50). Anything greater than zero will make black\n"
			   "   appear washed out, though readability can be improved in sunlight.\n"
			   "t: corrects the display temperature. Default is 6500K (which may or may not\n"
			   "   match your display), smaller values will appear warmer and can be easier to\n"
			   "   the eyes, while greater values appear more blueish.\n"
			   "d: sets the delay in seconds after which the app is woken up and the display\n"
			   "   settings are re-applied. All settings aside from the brightness (≥0) require\n"
			   "   the app to be kept running because other software or OS X itself may revert\n"
			   "   to default values. We recommend passing 30, which has litterally zero\n"
			   "   incidence on CPU and battery life, while reverting settings in case of need.\n"
			   "--silent: do not display a notification in the right corner of the screen.\n"
			   "--nosave: by default, saves the config for the next call, so that unmodified\n"
			   "   parameters get restored to the same as the last call.\n");
		return 0;
	}

	if (wantNotifications) {
		SetupForNotifications();
	}
		
	if (touchesBrightness) {
		ApplyLedBrightness(&params);
	}

	if (saveConfig) {
		saveCurrentBrightnessToFile(&params);
	}
	
	// Need to keep running?
	if (params.brightness >= 0 && fabsf(params.addition) < FLT_EPSILON && fabsf(params.gamma - 1) < FLT_EPSILON && fabsf(params.temperature - 6500) < FLT_EPSILON) {
		printf("Closing immediately\n");
		if (wantNotifications)
			ShowNotification(&params, NO, touchesBrightness);
	}
	else {
		printf("Running loop\n");
		if (wantNotifications)
			ShowNotification(&params, YES, touchesBrightness);
		GammaModifyLoop(kCGDirectMainDisplay, fminf(1, 1 - params.brightness / -100.f), params.gamma, params.addition, params.temperature, params.delayUs);
	}

    return 0;
}
