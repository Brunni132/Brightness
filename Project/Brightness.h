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
typedef struct {
	int brightness;
	int delayUs;
	float addition;
	float gamma;
	float temperature;
	BOOL blueSave;
} BrightnessParams;

void initBrightnessParams(BrightnessParams *dest);
void getCurrentBrightnessFromFile(BrightnessParams *dest);
void saveCurrentBrightnessToFile(BrightnessParams *value);

/** Brightness (screen affecting) API */
void ApplyLedBrightness(BrightnessParams *params);		// Only affects the backlight! Use GammaModifyLoop for the rest.
void GammaModifyLoop(CGDirectDisplayID display, float factor, float gamma, float brightnessAdd, float temperature, BOOL useBlueSave, uint32_t delay);		// Blocking. Does not change the LCD brightness.
