#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#import "Brightness.h"
#import "Notifications.h"

static void applyParams(CGDirectDisplayID *displays, unsigned displayCount, BrightnessParams *params) {
	GammaModifyLoop(displays, displayCount, fminf(1, 1 - params->brightness / -100.f), params->gamma, params->addition, params->temperature, params->blueSaveFactor, params->compensateGamma, params->delayUs);
}

static void applyParamsSingle(CGDirectDisplayID display, BrightnessParams *params) {
	applyParams(&display, 1, params);
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
int main(int argc, char *argv[]) {
	const int ALL_SCREENS = -1;
	BOOL wantNotifications = YES, showHelp = NO;
	BOOL saveConfig = NO; /* if yes, save the modified params only (kept in modifiedParams) */
	int screenId = 0;
	SavedBrightnessParams savedParams = 0, modifiedParams = 0, forceSavedParams = 0;
	BrightnessParams loadedParams, params;
	getSavedParamsFromFile(&loadedParams, &savedParams);
	params = loadedParams; // copy
	
	// Argument parsing
	for (int i = 1; i < argc; i++) {
		if (!strncmp(argv[i], "--sil", 5))
			wantNotifications = NO;
		else if (!strncmp(argv[i], "--sav", 5))
			saveConfig = YES;
		else if (!strncmp(argv[i], "--hel", 5))
			showHelp = YES;
		else if (!strncmp(argv[i], "--def", 5)) // Do not save any parameter
			initBrightnessParams(&params), modifiedParams = savedParams = 0;
		else if (!strncmp(argv[i], "--blu", 5)) {
			if (i + 1 < argc && argv[i + 1][0] >= '0' && argv[i + 1][0] <= '9')
				params.blueSaveFactor = atof(argv[++i]);
			else
				params.blueSaveFactor = 1.1111f;
			modifiedParams |= kParamBlueSave;
		}
		else if (!strncmp(argv[i], "--tem", 5))
			params.blueSaveFactor = 0.0f, modifiedParams |= kParamBlueSave;
		else if (!strncmp(argv[i], "--rea", 5)) {
			if (i + 1 < argc && argv[i + 1][0] >= '0' && argv[i + 1][0] <= '9')
				params.compensateGamma = atof(argv[++i]);
			else
				params.compensateGamma = 0.7f;
			modifiedParams |= kParamCompensateGamma;
		}
		else if (!strncmp(argv[i], "--scr", 5) && i + 1 < argc) {
			if (!strcmp(argv[++i], "all"))
				screenId = ALL_SCREENS;
			else
				screenId = atoi(argv[i]);
		}
		else if (argv[i][0] == 'g')
			params.gamma = atof(argv[i] + 1), modifiedParams |= kParamGamma;
		else if (argv[i][0] == 'b')
			params.addition = atof(argv[i] + 1) / 100.0f, modifiedParams |= kParamAddition;
		else if (argv[i][0] == 't')
			params.temperature = atof(argv[i] + 1), modifiedParams |= kParamTemperature;
		else if (argv[i][0] == 'd')
			params.delayUs = (uint32_t) (atof(argv[i] + 1) * 1000000.f), modifiedParams |= kParamDelay;
		else if (argv[i][0] == '+' || argv[i][0] == '-')
			params.brightness += atoi(argv[i]), forceSavedParams |= kParamBrightness;
		else if (argv[i][0] >= '0' && argv[i][0] <= '9')
			params.brightness = atoi(argv[i]), forceSavedParams |= kParamBrightness;
		else
			printf("Unrecognized option %s, aborting\n", argv[i]), showHelp = YES;
	}
		
	if (showHelp) {
		printf("Usage: brightness +5 g1.0 a0.0 t6500 d30 --silent\n"
			   "Configures the brightness of non-Apple external displays and other goodies. All\n"
			   "    arguments are optional.\n"
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
			   "--bluesave: The temperature modification algorithm is design to limit the blue\n"
			   "   emissions of your screen, like on iOS 9.3. Optionally dd a number between 0\n"
			   "   and 2 to make the screen more yellow. Use --temperature to revert.\n"
			   "--save: save the config for the next call, so that unmodified parameters get\n"
			   "   restored to the same as the last call. Brightness is always saved.\n"
			   "--default: starts with default parameters instead of previously saved ones.\n"
			   "   Takes effect from the point where located on the command line, so you should\n"
			   "   come as the first option.\n"
			   "--real: Compensates the redishness of screen to make the colors look more\n"
			   "   natural (experimental). Add a number [0-1], default is 0.7.\n"
			   "--screen: Number of the screen to apply to (not saved). Starts at 1. Try 'all'.\n"
		);
		return 0;
	}
	
	transferParameters(&params, &loadedParams, forceSavedParams);
	savedParams |= forceSavedParams;
	
	if (saveConfig) {
		transferParameters(&params, &loadedParams, modifiedParams);
		savedParams |= modifiedParams;
	}

	if (wantNotifications) {
		SetupForNotifications();
	}

	BOOL touchesBrightness = (modifiedParams & kParamBrightness) != 0;
	if (touchesBrightness) {
		ApplyLedBrightness(&params);
	}

	if (savedParams) {
		saveParamsToFile(&loadedParams, savedParams);
	}
	else {
		deleteParamsFile();
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

		if (screenId != 0) {
			CGDirectDisplayID activeDisplays[32];
			uint32_t actualCount;
			CGGetOnlineDisplayList(sizeof(activeDisplays) / sizeof(activeDisplays[0]), activeDisplays, &actualCount);
			if (screenId == ALL_SCREENS) { // Apply on all screens
				applyParams(activeDisplays, actualCount, &params);
			}
			else if (screenId > (int)actualCount) {
				fprintf(stderr, "Tried to apply to screen %d but only %d displays are connected.\n", screenId, actualCount);
				return 0;
			}
			else // Apply on designated screen
				applyParamsSingle(activeDisplays[screenId - 1], &params);
		}
		else // Apply on default screen
			applyParamsSingle(kCGDirectMainDisplay, &params);
	}

    return 0;
}
