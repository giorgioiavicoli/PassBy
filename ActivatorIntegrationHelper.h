#ifndef PASSBYACTIVATORHELPER_H
#define PASSBYACTIVATORHELPER_H

#include <libactivator/libactivator.h>

#define PASSBY_UNLOCK_LALISTENER_NAME       "com.giorgioiavicoli.passby.unlock"
#define PASSBY_INVALIDATE_LALISTENER_NAME   "com.giorgioiavicoli.passby.invalidate"

@interface PassByListener : NSObject <LAListener>
@end

@implementation PassByListener

- (void)activator:(LAActivator *)activator
    receiveEvent:(LAEvent *)event
    forListenerName:(NSString *)listenerName
{
    if ([listenerName isEqualToString:@PASSBY_UNLOCK_LALISTENER_NAME]) {
        unlockDevice(YES);
    } else {
        @synchronized(ManuallyDisabledSyncObj) {
            isDisabledUntilNext = YES;
        }
    }

    [event setHandled:YES];
}

- (NSString *)activator:(LAActivator *)activator
    requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	return @"PassBy";
}

- (NSString *)activator:(LAActivator *)activator
    requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	return
        [listenerName isEqualToString:@PASSBY_UNLOCK_LALISTENER_NAME]
            ? @"PassBy Unlock"
            : @"PassBy Disable Temporary";
}

- (NSString *)activator:(LAActivator *)activator
    requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
    return
        [listenerName isEqualToString:@PASSBY_UNLOCK_LALISTENER_NAME]
            ? @"Unlock the device and dismiss the lockscreen"
            : @"Disable PassBy until next real unlock";
}

- (NSArray *)activator:(LAActivator *)activator
    requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName
{
    return
        [listenerName isEqualToString:@PASSBY_UNLOCK_LALISTENER_NAME]
	        ? [NSArray arrayWithObjects:@"lockscreen", nil]
            : [NSArray arrayWithObjects:@"springboard", @"lockscreen", @"application", nil];
}




- (NSData *)activator:(LAActivator *)activator
    requiresIconDataForListenerName:(NSString *)listenerName
{
    return [NSData dataWithContentsOfFile:@"/Library/PreferenceBundles/PassByPrefs.bundle/icon@2x.png"];
}

- (NSData *)activator:(LAActivator *)activator
    requiresSmallIconDataForListenerName:(NSString *)listenerName
{
    return [NSData dataWithContentsOfFile:@"/Library/PreferenceBundles/PassByPrefs.bundle/icon.png"];
}

@end


#else
#error "File already included"
#endif // PASSBYACTIVATORHELPER_H