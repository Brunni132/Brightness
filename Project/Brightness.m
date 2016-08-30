#import "Brightness.h"

static BOOL BrightnessRead(IOI2CConnectRef connect, int *outMaxBrightnessValue, int *outReadBrightness) {
	IOI2CRequest request;
	UInt8 data[128];
	UInt8 inData[128];
	kern_return_t kr;
	int numTries = 0;		// try for ~1 second
	do {
		bzero( &request, sizeof(request));
		request.commFlags = 0;
		
		request.sendAddress = 0x6E;
		request.sendTransactionType = kIOI2CCombinedTransactionType;
		request.sendBuffer = (vm_address_t) &data[0];
		request.sendBytes = 5;
		request.minReplyDelay = 1<<30;
		
		data[0] = 0x51;
		data[1] = 0x82;
		data[2] = 0x01;
		data[3] = 0x10;
		data[4] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3];
		
		
		request.replyTransactionType = kIOI2CDDCciReplyTransactionType;
		request.replyAddress = 0x6F;
		request.replySubAddress = 0x51;
		request.replyBuffer = (vm_address_t) &inData[0];
		request.replyBytes = 11;
		bzero( &inData[0], request.replyBytes );
		
		kr = IOI2CSendRequest( connect, kNilOptions, &request );
		assert( kIOReturnSuccess == kr );
		if( kIOReturnSuccess != request.result)
			return NO;
		
		/*		int i;
		 for (i=0; i<11; i++)
		 printf(" 0x%x ",inData[i]);
		 printf("\n");*/
		usleep(30000);
		//		if (numTries++ == 0)		// do at least twice to clean up I2C
		//			continue;
	} while (inData[10] == 0xff && numTries < 30);
	
	*outMaxBrightnessValue = inData[7], *outReadBrightness = inData[9];
	return YES;
}

static void BrightnessModify(IOI2CConnectRef connect, int bright) {
	kern_return_t kr;
	IOI2CRequest request;
	UInt8 data[128];
	
	bzero( &request, sizeof(request));
	
	request.commFlags = 0;
	
	request.sendAddress = 0x6E;
	request.sendTransactionType = kIOI2CSimpleTransactionType;
	request.sendBuffer = (vm_address_t) &data[0];
	request.sendBytes = 7;
	
	data[0] = 0x51;
	data[1] = 0x84;
	data[2] = 0x03;
	data[3] = 0x10;
	data[4] = 0x64 ;
	data[5] = bright ;
	data[6] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3]^ data[4]^
	data[5];
	
	
	request.replyTransactionType = kIOI2CNoTransactionType;
	request.replyBytes = 0;//128;
	
	kr = IOI2CSendRequest( connect, kNilOptions, &request );
	assert( kIOReturnSuccess == kr );
	if (kIOReturnSuccess != request.result) {
		return;
	}
}

static void computeRamp(int tmpKelvin, float* rMultiplier, float* gMultiplier, float* bMultiplier) {
	double tmpCalc;
	tmpKelvin = fminf(40000, fmaxf(1000, tmpKelvin + 100));
	tmpKelvin = (int)lroundf(tmpKelvin / 100.0f);
	
	// Red
	if (tmpKelvin < 66) {} // *rMultiplier = 255;
	else {
		tmpCalc = tmpKelvin - 60;
		tmpCalc = 329.698727446f * powf(tmpCalc, -0.1332047592f);
		int mult = (int) fmaxf(0, fminf(255, tmpCalc));
		*rMultiplier *= mult / 255.0f;
	}
	
	// Green
	if (tmpKelvin <= 66) {
		tmpCalc = tmpKelvin;
		tmpCalc = 99.4708025861f * logf(tmpCalc) - 161.1195681661f;
		int mult = (int) fmaxf(0, fminf(255, tmpCalc));
		*gMultiplier *= mult / 255.0f;
	}
	else {
		tmpCalc = tmpKelvin - 60;
		tmpCalc = 288.1221695283f * powf(tmpCalc, -0.0755148492f);
		int mult = (int) fmaxf(0, fminf(255, tmpCalc));
		*gMultiplier *= mult / 255.0f;
	}
	
	// Blue
	if (tmpKelvin >= 66) {} // bMultiplier = 255;
	else if (tmpKelvin <= 19) *bMultiplier = 0;
	else {
		tmpCalc = tmpKelvin - 10;
		tmpCalc = 138.5177312231f * logf(tmpCalc) - 305.0447927307f;
		int mult = (int)fmaxf(0, fminf(255, tmpCalc));
		*bMultiplier *= mult / 255.0f;
	}
}

static void computeRampBlueSave(int tmpKelvin, float* rMultiplier, float* gMultiplier, float* bMultiplier) {
	double tmpCalc;
	
	// Red
	// *rMultiplier = 255;
	
	// Green
	tmpCalc = 255 - (6500 - tmpKelvin) * 0.016;
//	tmpCalc = 255 - (6500 - tmpKelvin) * 0.014;
//	tmpCalc = 255 - (6500 - tmpKelvin) * 0.005;
	int mult = (int) fmaxf(0, fminf(255, tmpCalc));
	*gMultiplier *= mult / 255.0f;
	
	// Blue
	tmpCalc = 255 - (6500 - tmpKelvin) * 0.038;
	mult = (int) fmaxf(0, fminf(255, tmpCalc));
	*bMultiplier *= mult / 255.0f;
}

static NSString *getFileName() {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *appSupportDirectoryPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"org.dev-fr.brunni.brightness"];
	NSFileManager *mgr = [NSFileManager defaultManager];
	NSError *error;
	if (![mgr fileExistsAtPath:appSupportDirectoryPath])
		[mgr createDirectoryAtPath:appSupportDirectoryPath withIntermediateDirectories:YES attributes:nil error:&error];
	return [appSupportDirectoryPath stringByAppendingPathComponent:@"currentBrightness"];
}

void initBrightnessParams(BrightnessParams *dest) {
	memcpy(dest->tag, kTag, sizeof(dest->tag));
	dest->gamma = 1, dest->addition = 0, dest->temperature = 6500;
	dest->brightness = 50, dest->delayUs = 30000000, dest->blueSave = NO;
}

void deleteParamsFile() {
	[[NSFileManager defaultManager] removeItemAtPath:getFileName() error:nil];
}

void getSavedParamsFromFile(BrightnessParams *dest, SavedBrightnessParams *loadedParams) {
	BrightnessParams readParams;
	NSData *data = [NSData dataWithContentsOfFile:getFileName()];
	initBrightnessParams(dest);
	
	if (!data) return;
	memcpy(&readParams, [data bytes], sizeof(BrightnessParams));
	
	// Check tag
	if (data && !memcmp(readParams.tag, kTag, sizeof(readParams.tag))) {
		if (readParams.savedParams & kParamBrightness) dest->brightness = readParams.brightness;
		if (readParams.savedParams & kParamDelay) dest->delayUs = readParams.delayUs;
		if (readParams.savedParams & kParamAddition) dest->addition = readParams.addition;
		if (readParams.savedParams & kParamGamma) dest->gamma = readParams.gamma;
		if (readParams.savedParams & kParamTemperature) dest->temperature = readParams.temperature;
		if (readParams.savedParams & kParamBlueSave) dest->blueSave = readParams.blueSave;
		if (loadedParams) *loadedParams = readParams.savedParams;
	}
}

void saveParamsToFile(BrightnessParams *value, SavedBrightnessParams toSave) {
	if (!toSave) return;
	
	BrightnessParams existing;
	getSavedParamsFromFile(&existing, NULL);

	existing.savedParams = toSave;
	if (toSave & kParamBrightness) existing.brightness = value->brightness;
	if (toSave & kParamDelay) existing.delayUs = value->delayUs;
	if (toSave & kParamAddition) existing.addition = value->addition;
	if (toSave & kParamGamma) existing.gamma = value->gamma;
	if (toSave & kParamTemperature) existing.temperature = value->temperature;
	if (toSave & kParamBlueSave) existing.blueSave = value->blueSave;

	NSData *data = [NSData dataWithBytes:&existing length:sizeof(BrightnessParams)];
	if (![[NSFileManager defaultManager] createFileAtPath:getFileName() contents:data attributes:nil]) {
		fprintf(stderr, "Failed to write %s\n", [getFileName() cStringUsingEncoding:NSUTF8StringEncoding]);
	}
}

void ApplyLedBrightness(BrightnessParams *params) {
	kern_return_t kr;
	io_service_t framebuffer, interface;
	IOOptionBits bus;
	IOItemCount busCount;
	framebuffer = CGDisplayIOServicePort(CGMainDisplayID());
	{
		io_string_t path;
		kr = IORegistryEntryGetPath(framebuffer, kIOServicePlane, path);
		assert( KERN_SUCCESS == kr );
		
		kr = IOFBGetI2CInterfaceCount( framebuffer, &busCount );
		assert( kIOReturnSuccess == kr );
		
		for( bus = 0; bus < busCount; bus++ )
		{
			IOI2CConnectRef connect;
			
			kr = IOFBCopyI2CInterfaceForBus(framebuffer, bus, &interface);
			if( kIOReturnSuccess != kr)
				continue;
			
			kr = IOI2CInterfaceOpen( interface, kNilOptions, &connect );
			
			IOObjectRelease(interface);
			assert( kIOReturnSuccess == kr );
			if( kIOReturnSuccess != kr)
				continue;
			
			// Old and incomplete code (prior to refactoring, everything was in Main.m); the readBrightness would be used and then params.brightness would be readBrightness + affected brightness (relatively) in the argument parsing phase.
//			int minValue = -80, maxValue, readBrightness;
//			BrightnessRead(connect, &maxValue, &readBrightness);
			// HACK because some screens/graphic card report invalid values
			int minValue = -80, maxValue = 100;
			if (params->brightness == 0xff) {
				printf("Could not read brightness\n");
			}
			else {
//				printf("Current brightness = %d (min = %d, max = %d)\n", currentValue, minValue, maxValue);
				params->brightness = (int)fmaxf(minValue, fminf(params->brightness, maxValue));
				BrightnessModify(connect, fmaxf(0, params->brightness));
			}
			IOI2CInterfaceClose(connect, kNilOptions);
			break;
		}
	}
}

void GammaModifyLoop(CGDirectDisplayID *displays, unsigned displayCount, float factor, float gamma, float brightnessAdd, float temperature, BOOL useBlueSave, uint32_t delay) {
	struct CGGammaParams {
		CGGammaValue redMin, redMax, redGamma,
		             greenMin, greenMax, greenGamma,
		             blueMin, blueMax, blueGamma;
	};
	struct CGGammaParams *params = calloc(displayCount, sizeof(struct CGGammaParams));

//	if (factor > 1.0f) {
//		CGDisplayRestoreColorSyncSettings();
//		return;
//	}

	for (int i = 0; i < displayCount; i++) {
		CGGetDisplayTransferByFormula(displays[i],
									  &params[i].redMin, &params[i].redMax, &params[i].redGamma,
									  &params[i].greenMin, &params[i].greenMax, &params[i].greenGamma,
									  &params[i].blueMin, &params[i].blueMax, &params[i].blueGamma);

		if (temperature > 6500)
			computeRamp(temperature, &params[i].redMax, &params[i].greenMax, &params[i].blueMax);
		else if (temperature >= 1000 && temperature < 6500 && !useBlueSave)
			computeRamp(temperature, &params[i].redMax, &params[i].greenMax, &params[i].blueMax);
		else
			computeRampBlueSave(temperature, &params[i].redMax, &params[i].greenMax, &params[i].blueMax);
	}

	while (true) {
		for (int i = 0; i < displayCount; i++) {
			CGSetDisplayTransferByFormula(displays[i],
										  params[i].redMin + brightnessAdd, factor*params[i].redMax, params[i].redGamma / gamma,
										  params[i].greenMin + brightnessAdd, factor*params[i].greenMax, params[i].greenGamma / gamma,
										  params[i].blueMin + brightnessAdd, factor*params[i].blueMax, params[i].blueGamma / gamma);
		}
		usleep(delay);
	}

	free(params);
}

