#import "FSSwitchPanel.h"
#import <AudioToolbox/AudioServices.h>

#define AS_DEFAULT_ENABLED YES
#define AS_DEFAULT_PERCENTAGE 2
#define AS_DEFAULT_DELAY 5
#define AS_DEFAULT_CHECK NO
#define AS_DEFAULT_CHECKMIN 300
#define AS_DEFAULT_FORCE_WIFI NO
#define AS_DEFAULT_DOWNGRADE_NETWORK NO
#define AS_SETTINGS_DOMAIN CFSTR("com.joemerlino.airplanesignal")
#define AS_3G_SWITCH_ID "com.a3tweaks.switch.3g"
#define AS_LTE_SWITCH_ID "com.a3tweaks.switch.lte"
#ifndef kCFCoreFoundationVersionNumber_iOS_8_0
	#define kCFCoreFoundationVersionNumber_iOS_8_0 1129.15
#endif

typedef void(^cancel_block_t)(void);
typedef enum {
	ASNetworkSpeedSlow = 0,
	ASNetworkSpeedFast = 1,
} ASNetworkSpeed;

static BOOL call = NO;
static int percentage = AS_DEFAULT_PERCENTAGE;
static BOOL enabled = AS_DEFAULT_ENABLED;
static int bars = 0;
static int lastTriggerBars = INT_MAX;
static cancel_block_t cancelBlock = NULL;
static BOOL wifi = NO;
static BOOL bluetooth = NO;
static int delay = AS_DEFAULT_DELAY;
static BOOL check = AS_DEFAULT_CHECK;
static int checkmin = AS_DEFAULT_CHECKMIN;
static BOOL forcewifi = AS_DEFAULT_FORCE_WIFI;
static BOOL tryDownGradeNetworkSpeed = AS_DEFAULT_DOWNGRADE_NETWORK;
static BOOL didDowngradeNetworkSpeed = NO;
static BOOL disabledWhileNetworkChange = NO;
static BOOL disableNetworkChange = NO;

@interface ASFlipSwitchNotificationHelper : NSObject
+ (void)startListeningForNotifications;
@end

@implementation ASFlipSwitchNotificationHelper 

+ (void)startListeningForNotifications {
	static dispatch_once_t onceToken;
	static ASFlipSwitchNotificationHelper* instance;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
}

- (instancetype)init {
	if((self = [super init])){
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(flipSwitchChanged:) name:FSSwitchPanelSwitchStateChangedNotification object:nil];
	}
	return self;
}

- (void)flipSwitchChanged:(NSNotification *)notification {
	NSString* switchID = [[[notification userInfo] valueForKey:FSSwitchPanelSwitchIdentifierKey] retain];
	if(switchID != nil && ([@AS_3G_SWITCH_ID isEqualToString:switchID] || [@AS_LTE_SWITCH_ID isEqualToString:switchID])) {
		if(!disabledWhileNetworkChange && didDowngradeNetworkSpeed && canDowngradeNetworkSpeed()){
			//user enabled 3G/LTE after we disabled it.
			NSLog(@"[AirplaneSignal] user did enable 3G/LTE after we disabled!");
			didDowngradeNetworkSpeed = NO;
		}
	}
	[switchID release];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:FSSwitchPanelSwitchStateChangedNotification object:nil];
	[super dealloc];
}

@end

cancel_block_t create_and_run_cancelable_dispatch_after_block(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block) {
	if(!block) {
		return NULL;
	}
	__block BOOL canceled = NO;
	cancel_block_t cancel_block = [^{
		canceled = YES;
	} copy];
	if(!queue){
		queue = dispatch_get_main_queue();
	}
	dispatch_after(when, queue, ^{
		if(!canceled) {
			block();
		}
	});
	return [cancel_block retain];
}

static BOOL canDowngradeNetworkSpeed() {
	return ([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@AS_LTE_SWITCH_ID] == FSSwitchStateOn) || ([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@AS_3G_SWITCH_ID] == FSSwitchStateOn);
}

static BOOL setNetworkSpeed(ASNetworkSpeed speed) {
	BOOL changed = NO;
	disabledWhileNetworkChange = YES;
	if(!call){
		if(speed == ASNetworkSpeedFast) {
			NSLog(@"[AirplaneSignal] Try to upgrade network speed.");
		}
		//new Phones with LTE
		if ((![[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@AS_LTE_SWITCH_ID]) == speed) {
			[[FSSwitchPanel sharedPanel] setState:(FSSwitchState)speed forSwitchIdentifier:@AS_LTE_SWITCH_ID];
			changed = YES;
		}
		//old Phones without LTE
		if ((![[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@AS_3G_SWITCH_ID]) == speed) {
			[[FSSwitchPanel sharedPanel] setState:(FSSwitchState)speed forSwitchIdentifier:@AS_3G_SWITCH_ID];
			changed = YES;
		}
		if(changed){
			disableNetworkChange = YES;
			//15 seconds, so it has time to switch to other Network (In that period iOS always returns only 1 bar)
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				disabledWhileNetworkChange = NO;
			});
			//dont get in a loop of nonstop down an upgrading, wait for some time
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, checkmin * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				disableNetworkChange = NO;
			});
			return !speed;
		}
	}
	disabledWhileNetworkChange = NO;
	return NO;
}

static void handleSignalStrengthUpdate(){
	NSLog(@"[AirplaneSignal] P: %d BARS: %d CALL: %d", percentage, bars, call);
	if(enabled && !disabledWhileNetworkChange){
		if(percentage>=bars){
			if(lastTriggerBars>=bars){
				if(!cancelBlock){
					NSLog(@"[AirplaneSignal] queueing block");
					cancelBlock = create_and_run_cancelable_dispatch_after_block(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
						NSLog(@"[AirplaneSignal] executing queued block");
						NSLog(@"[AirplaneSignal] P: %d BARS: %d CALL: %d", percentage, bars, call);
						//recheck bars nevertheless
						if(percentage>=bars) {
							if(tryDownGradeNetworkSpeed && !disableNetworkChange && !didDowngradeNetworkSpeed && canDowngradeNetworkSpeed()) {
								didDowngradeNetworkSpeed = setNetworkSpeed(ASNetworkSpeedSlow);
								NSLog(@"[AirplaneSignal] Could downgrade network speed: %d", didDowngradeNetworkSpeed);
								if(didDowngradeNetworkSpeed) {
									AudioServicesPlaySystemSound(1352);
								}
							} else if(!call){
								BOOL tryToRestoreNetworkSpeed = didDowngradeNetworkSpeed;
								if([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"] == 0){
									wifi = [[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.wifi"] == FSSwitchStateOn;
								    bluetooth = [[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.bluetooth"] == FSSwitchStateOn;
									[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOn forSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"];
									AudioServicesPlaySystemSound(1352);
									NSLog(@"[AirplaneSignal] AIRPLANEMODE ON, WIFI %d, BT %d",wifi, bluetooth); 
									if(wifi || forcewifi)
										[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOn forSwitchIdentifier:@"com.a3tweaks.switch.wifi"];
									if(bluetooth)
										[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOn forSwitchIdentifier:@"com.a3tweaks.switch.bluetooth"];
									if(check){
										BOOL tryToRestoreNetworkSpeedBlock = tryToRestoreNetworkSpeed;
										dispatch_after(dispatch_time(DISPATCH_TIME_NOW, checkmin * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
											if([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"] == FSSwitchStateOn)
												[[FSSwitchPanel sharedPanel] setState:FSSwitchStateOff forSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"];
											if(tryToRestoreNetworkSpeedBlock && !disableNetworkChange){
												didDowngradeNetworkSpeed = setNetworkSpeed(ASNetworkSpeedFast);
											}
										});
									}
									tryToRestoreNetworkSpeed = NO;
								}
								if(tryToRestoreNetworkSpeed && !disableNetworkChange){
									didDowngradeNetworkSpeed = setNetworkSpeed(ASNetworkSpeedFast);
								}
							}
						}
						[cancelBlock release];
						cancelBlock = NULL;
					});
				}
				goto returnLabel;
			}
		}
		if(cancelBlock) {
			//Signal strength got better
			NSLog(@"[AirplaneSignal] cancel queued block");
			cancelBlock();
			[cancelBlock release];
			cancelBlock = NULL;
			if(didDowngradeNetworkSpeed && !disableNetworkChange) {
				didDowngradeNetworkSpeed = setNetworkSpeed(ASNetworkSpeedFast);
			}
		}
		returnLabel:
		lastTriggerBars = bars;
	}
}

%hook SBTelephonyManager

%group OS7Hooks
- (int)signalStrengthBars{
	bars = %orig;
	handleSignalStrengthUpdate();
	return bars;
}

-(_Bool)inCall{
	call=%orig;
	NSLog(@"INCALL %d",call);
	return (_Bool)call;
}
%end

%group OS8Hooks
-(BOOL)inCall{
	call = %orig;
	NSLog(@"INCALL %d",call);
	return call;
}
-(long)signalStrengthBars{
	bars = %orig;
	handleSignalStrengthUpdate();
	return bars;
}
%end

%end

static void LoadSettings(){
	CFPreferencesAppSynchronize(CFSTR("com.joemerlino.airplanesignal"));
	NSNumber *n = (NSNumber*)CFPreferencesCopyAppValue(CFSTR("enabled"), AS_SETTINGS_DOMAIN);
	enabled = (n) ? [n boolValue]:AS_DEFAULT_ENABLED;
	NSNumber *n2 = (NSNumber*)CFPreferencesCopyAppValue(CFSTR("percentage"), AS_SETTINGS_DOMAIN);
 	percentage = (n2) ? [n2 intValue]:AS_DEFAULT_PERCENTAGE;
 	NSNumber *n3 = (NSNumber*)CFPreferencesCopyAppValue(CFSTR("delay"), AS_SETTINGS_DOMAIN);
	delay = (n3) ? [n3 intValue]:AS_DEFAULT_DELAY;
	NSNumber *n4 = (NSNumber*)CFPreferencesCopyAppValue(CFSTR("check"), AS_SETTINGS_DOMAIN);
	check = (n4) ? [n4 boolValue]:AS_DEFAULT_CHECK;
	NSNumber *n5 = (NSNumber*)CFPreferencesCopyAppValue(CFSTR("checkmin"), AS_SETTINGS_DOMAIN);
	checkmin = (n5) ? [n5 intValue]:AS_DEFAULT_CHECKMIN;
	NSNumber *n6 = (NSNumber*)CFPreferencesCopyAppValue(CFSTR("forcewifi"), AS_SETTINGS_DOMAIN);
	forcewifi = (n6) ? [n6 boolValue]:AS_DEFAULT_FORCE_WIFI;
	NSNumber *n7 = (NSNumber*)CFPreferencesCopyAppValue(CFSTR("downgradenetwork"), AS_SETTINGS_DOMAIN);
	tryDownGradeNetworkSpeed = (n7) ? [n7 boolValue]:AS_DEFAULT_DOWNGRADE_NETWORK;
 	NSLog(@"[AirplaneSignal] ENABLED AIRPLANESIGNAL: %d PERCENTAGE %d", enabled, percentage);
}
	
%ctor
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)LoadSettings, CFSTR("com.joemerlino.airplanesignal.preferencechanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	LoadSettings();
	[ASFlipSwitchNotificationHelper startListeningForNotifications];
	if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0)
		%init(OS8Hooks);
	else
		%init(OS7Hooks);
}
