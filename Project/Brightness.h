//
//  Module: Brightness
//  Brightness
//
//  Created by Florian on 04/09/15.
//
//  Controls the brightness of the external screen (DDC/CI connected) and the gamma ramp of any (main) display
//
#import <Foundation/Foundation.h>
#include <IOKit/IOKitLib.h>
#include <ApplicationServices/ApplicationServices.h>
#include <IOKit/i2c/IOI2CInterface.h>

/** Brightness parameters API */
typedef enum {
	kParamBrightness = 1 << 0,
	kParamDelay = 1 << 1,
	kParamAddition = 1 << 2,
	kParamGamma = 1 << 3,
	kParamTemperature = 1 << 4,
	kParamBlueSave = 1 << 5,
	kParamCompensateGamma = 1 << 6,
	kParamAll = (1 << 7) - 1
} SavedBrightnessParams;

#define kTag "brightness\0"

typedef struct {
	char tag[12];
	SavedBrightnessParams savedParams;
	int brightness;
	int delayUs;
	float addition;
	float gamma;
	float temperature;
	BOOL blueSave;
	float compensateGamma;
} BrightnessParams;

void initBrightnessParams(BrightnessParams *dest);
void deleteParamsFile();
void getSavedParamsFromFile(BrightnessParams *dest, SavedBrightnessParams *loadedParams);
void transferParameters(BrightnessParams *originalParams, BrightnessParams *outParams, SavedBrightnessParams params);
void saveParamsToFile(BrightnessParams *value, SavedBrightnessParams toSave);

/** Brightness (screen affecting) API */
void ApplyLedBrightness(BrightnessParams *params);		// Only affects the backlight! Use GammaModifyLoop for the rest.
void GammaModifyLoop(CGDirectDisplayID *displays, unsigned displayCount, float factor, float gamma, float brightnessAdd, float temperature, BOOL useBlueSave, float compensateGamma, uint32_t delay);		// Blocking. Does not change the LCD brightness.
