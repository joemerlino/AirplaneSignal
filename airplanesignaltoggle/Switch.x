#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"
#include <CoreFoundation/CFNotificationCenter.h>
#import <notify.h>

static NSString * const domainString = @"/var/mobile/Library/Preferences/com.joemerlino.airplanesignal.plist";
static NSString * const kSwitchKey = @"enabled";

@interface NSUserDefaults (UFS_Category)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end

@interface AirplaneSignalToggleSwitch : NSObject <FSSwitchDataSource>
@end

@implementation AirplaneSignalToggleSwitch

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier {
	return @"AirplaneSignal";
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSNumber *n = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:kSwitchKey inDomain:domainString];
    BOOL enabled = (n) ? [n boolValue]:YES;
    return (enabled) ? FSSwitchStateOn : FSSwitchStateOff;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	switch (newState) {
    case FSSwitchStateIndeterminate:
        break;
    case FSSwitchStateOn:
        [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:kSwitchKey inDomain:domainString];
        [[NSUserDefaults standardUserDefaults] synchronize];
        break;
    case FSSwitchStateOff:
        [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:kSwitchKey inDomain:domainString];
        [[NSUserDefaults standardUserDefaults] synchronize];
        break;
    }
    notify_post("com.joemerlino.airplanesignal.preferencechanged");
}

@end