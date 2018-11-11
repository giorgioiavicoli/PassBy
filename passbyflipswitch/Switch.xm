#include <notify.h>
#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"

@interface NSUserDefaults (Tweak_Category)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end

#define FSPACKAGENAME 	"com.giorgioiavicoli.passbyflipswitch"
#define FSTURNONNOTI 	"com.giorgioiavicoli.passbyflipswitch/on"
#define FSTURNOFFNOTI 	"com.giorgioiavicoli.passbyflipswitch/off"

@interface PassByFlipswitchSwitch : NSObject <FSSwitchDataSource>
@end

@implementation PassByFlipswitchSwitch

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier 
{
	return @"PassBy Flipswitch";
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier 
{
	return
		[	(	[	[NSUserDefaults standardUserDefaults]
					objectForKey:@"enabled" 
					inDomain:@FSPACKAGENAME
				]?: [NSNumber numberWithBool:YES] 
			) boolValue
		] ? 
		FSSwitchStateOn 
		: FSSwitchStateOff;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier {
	BOOL state = (newState == FSSwitchStateOn);
	[	[NSUserDefaults standardUserDefaults] 
		setObject:[NSNumber numberWithBool:state] 
		forKey:@"enabled" 
		inDomain:@FSPACKAGENAME
	];

	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(), 
		(state ? CFSTR(FSTURNONNOTI) : CFSTR(FSTURNOFFNOTI)),
		NULL, NULL, 
		CFNotificationSuspensionBehaviorCoalesce
	);
}

@end
