#import "FSSwitchPanel.h"
#import <AudioToolbox/AudioServices.h>

static BOOL call = NO;
static int percentage = 2;
static BOOL enabled = YES;
static int bars = 0;
static BOOL wifi = NO;
static BOOL bluetooth = NO;
static int delay = 5;
static BOOL check = NO;
static int checkmin = 300;
static BOOL forcewifi = NO;

#ifndef kCFCoreFoundationVersionNumber_iOS_8_0
	#define kCFCoreFoundationVersionNumber_iOS_8_0 1129.15
#endif

#define setin_domain CFSTR("com.joemerlino.airplanesignal")

%hook SBTelephonyManager

%group OS7Hooks
- (int)signalStrengthBars{
	bars = %orig;
	NSLog(@"[AirplaneSignal] P: %d BARS: %d CALL: %d", percentage, bars, call);
	if(enabled && percentage>=bars){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			NSLog(@"[AirplaneSignal] P: %d BARS: %d CALL: %d", percentage, bars, call);
			if(!call && percentage>=bars && [[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"] == 0){
				if ([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.wifi"] == 1)
			        wifi = YES;
			    else wifi = NO;
			    if ([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.bluetooth"] == 1)
			        bluetooth = YES;
			    else bluetooth = NO;
				[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOn forSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"];
				AudioServicesPlaySystemSound(1352);
				NSLog(@"[AirplaneSignal] AIRPLANEMODE ON, WIFI %d, BT %d",wifi, bluetooth); 
				if(wifi || forcewifi)
					[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOn forSwitchIdentifier:@"com.a3tweaks.switch.wifi"];
				if(bluetooth)
					[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOn forSwitchIdentifier:@"com.a3tweaks.switch.bluetooth"];
				if(check){
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, checkmin * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
						if([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"] == 1)
							[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOff forSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"];
					});
				}
			}
		});
	}  
	return %orig;
}

-(_Bool)inCall{
	NSLog(@"INCALL %d",%orig);
	call=%orig;
	return %orig;
}
%end

%group OS8Hooks
-(BOOL)inCall{
	call = %orig;
	return %orig;
}
-(long)signalStrengthBars{
	bars = %orig;
	NSLog(@"[AirplaneSignal] P: %d BARS: %d CALL: %d", percentage, bars, call);
	if(enabled && percentage>=bars){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			NSLog(@"[AirplaneSignal] P: %d BARS: %d CALL: %d", percentage, bars, call);
			if(!call && percentage>=bars && [[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"] == 0){
				if ([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.wifi"] == 1)
			        wifi = YES;
			    else wifi = NO;
			    if ([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.bluetooth"] == 1)
			        bluetooth = YES;
			    else bluetooth = NO;
				[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOn forSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"];
				AudioServicesPlaySystemSound(1352);
				NSLog(@"[AirplaneSignal] AIRPLANEMODE ON, WIFI %d, BT %d",wifi, bluetooth); 
				if(wifi || forcewifi)
					[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOn forSwitchIdentifier:@"com.a3tweaks.switch.wifi"];
				if(bluetooth)
					[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOn forSwitchIdentifier:@"com.a3tweaks.switch.bluetooth"];
				if(check){
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, checkmin * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
						if([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"] == 1)
							[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOff forSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"];
					});
				}
			}
		});
	}  
	return %orig;
}
%end

%end
static void LoadSettings(){
	CFPreferencesAppSynchronize(CFSTR("com.joemerlino.airplanesignal"));
	NSString *n = (NSString*)CFPreferencesCopyAppValue(CFSTR("enabled"), setin_domain);
	enabled = (n) ? [n boolValue]:YES;
	NSString *n2 = (NSString*)CFPreferencesCopyAppValue(CFSTR("percentage"), setin_domain);
 	percentage = [n2 intValue];
 	NSString *n3 = (NSString*)CFPreferencesCopyAppValue(CFSTR("delay"), setin_domain);
	delay = [n3 intValue];
	NSString *n4 = (NSString*)CFPreferencesCopyAppValue(CFSTR("check"), setin_domain);
	check = (n4) ? [n4 boolValue]:NO;
	NSString *n5 = (NSString*)CFPreferencesCopyAppValue(CFSTR("checkmin"), setin_domain);
	checkmin = [n5 intValue];
	NSString *n6 = (NSString*)CFPreferencesCopyAppValue(CFSTR("forcewifi"), setin_domain);
	forcewifi = (n6) ? [n6 boolValue]:NO;
 	NSLog(@"[AirplaneSignal] ENABLED AIRPLANESIGNAL: %d PERCENTAGE %d", enabled, percentage);
}
	
%ctor
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)LoadSettings, CFSTR("com.joemerlino.airplanesignal.preferencechanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	LoadSettings();
	if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0)
		%init(OS8Hooks);
	else
		%init(OS7Hooks);
}
