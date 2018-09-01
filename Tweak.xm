#import <Foundation/Foundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <notify.h>

static BOOL isTweakEnabled;
static BOOL isReversed;
static BOOL shouldAlwaysShowTime;
static BOOL use24hFormat;
static BOOL isSixDigitPasscode;

static int      timeShift;

static NSString *   truePasscode    = nil;
static NSString *   lastTwoDigits   = nil;
static NSDate   *   lastTrueUnlock  = nil;
static NSDate   *   gracePeriodEnds = nil;

static unsigned long long lastLockstate = 3;

#define PLIST_PATH                  "/var/mobile/Library/Preferences/com.giorgioiavicoli.timepass.plist"
#define LOCKSTATE_NEEDSAUTH_MASK    0x02
#define GRACE_PERIOD_SECS           10
#define GRACE_PERIOD_WIFI_SECS      60

//#define LOGLINE NSLog(@"*g* %d %s", __LINE__, __FUNCTION__);
//#define NSLog(...)


NSString * stringFromDateAndFormat(NSDate * date, NSString * format);
NSMutableString * reverseStr(NSString *string);
NSString * magicPasscode();


static void updateLastTrueUnlock()
{
    [lastTrueUnlock     release];
    lastTrueUnlock  =   [NSDate new];
    NSLog(@"*g* updated lastTrueUnlock");
}

static void updateGracePeriod()
{
    [gracePeriodEnds    release];
    // if wifi
    BOOL isOnWifi = [((NSDictionary *) CNCopyCurrentNetworkInfo(CFSTR("en0")))[@"SSID"] isEqualToString:@"Vodafone-33933659"];

    unsigned long gracePeriod = isOnWifi 
                                ? GRACE_PERIOD_WIFI_SECS 
                                : GRACE_PERIOD_SECS;
    
    NSLog(@"*g* updating grace period to %lu", gracePeriod);
    
    gracePeriodEnds =   [[[NSDate date] dateByAddingTimeInterval: gracePeriod] retain];
}


@interface SBLockScreenManager : NSObject
@property(readonly) BOOL isUILocked;
+ (id)sharedInstance;
//- (BOOL)attemptUnlockWithPasscode:(id)arg1;
- (void)attemptUnlockWithPasscode:(id)arg1 completion:(/*^block*/id)arg2 ;
- (BOOL)_attemptUnlockWithPasscode:(id)arg1 finishUIUnlock:(BOOL)arg2;
@end

%hook SBLockScreenManager
- (void)attemptUnlockWithPasscode:(NSString*)passcode completion:(id)arg2 
{
    if (!isTweakEnabled || !passcode || ![passcode length])
        return %orig;
    
    if (truePasscode && [truePasscode length]) { 
        if ([passcode isEqualToString:magicPasscode()]) {
            %orig(truePasscode, arg2);
        } else {
            %orig;
            if (![self isUILocked])
                dispatch_async(dispatch_get_main_queue(), ^{updateLastTrueUnlock(); });
        }
    } else {
        %orig;
        if (![self isUILocked]) {
            dispatch_async(dispatch_get_main_queue(), 
                ^{
                    UIAlertView *alert =    [   [UIAlertView alloc]
                                                initWithTitle:@"TimePass"
                                                message:@"TimePass enabled!"
                                                delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil
                                            ];
                    [alert show];
                    [alert release];

                    truePasscode = [passcode copy];
                    updateLastTrueUnlock();
                }
            );
        }
    }
}
%end



@interface SBUIPasscodeLockViewWithKeypad
- (id)statusTitleView;
@end

%hook SBUIPasscodeLockViewWithKeypad
- (id)statusTitleView
{
	if (!truePasscode) {
		UILabel *label = MSHookIvar<UILabel *>(self, "_statusTitleView");
		label.text = @"TimePass requires passcode";
		return label;
    } else if (lastTrueUnlock) {
        NSMutableString * str = [NSMutableString stringWithString:@"Last unlock was at "];
        [str appendString:stringFromDateAndFormat(lastTrueUnlock, use24hFormat ? @"HH:mm:ss" : @"hh:mm:ss")];

		UILabel *label = MSHookIvar<UILabel *>(self, "_statusTitleView");
		label.text = str;
		return label;
    }
    return %orig;
}
%end



@interface SBLockScreenViewControllerBase
- (BOOL)shouldShowLockStatusBarTime;
@end

%hook SBLockScreenViewControllerBase
- (BOOL)shouldShowLockStatusBarTime 
{
    return YES; //shouldAlwaysShowTime || %orig;
}
%end






NSString * magicPasscode() 
{
    NSMutableString * pass = [  stringFromDateAndFormat(   
                                    timeShift 
                                        ? [[NSDate date] dateByAddingTimeInterval:timeShift * 60]
                                        : [NSDate date],
                                    use24hFormat ? @"HHmm" : @"hhmm"
                                ) mutableCopy
                            ];
    if (isReversed)
        pass = reverseStr(pass);

    if (isSixDigitPasscode)
        [pass appendString: (lastTwoDigits && lastTwoDigits.length == 2) ? lastTwoDigits : @"00"];

    NSLog(@"*g* Pass would be: %@", pass);
    return pass;
}

NSString * stringFromDateAndFormat(NSDate * date, NSString * format)
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setLocale:[NSLocale currentLocale]];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:format];
    
    NSString * string = [formatter stringFromDate:date];
    [formatter release];
    return string;
}


NSMutableString * reverseStr(NSString *string) 
{
    NSInteger len = [string length];
    NSMutableString *reversed = [NSMutableString stringWithCapacity:len];
    
    for (NSInteger i = (len - 1); i >= 0; i--)
        [reversed appendFormat:@"%c", [string characterAtIndex:i]];

    return reversed;
}



@interface SBLockStateAggregator : NSObject
+(id)sharedInstance;
-(unsigned long long)lockState;
@end


static void timePassSettingsChanged(CFNotificationCenterRef center, void * observer, 
                                    CFStringRef name, void const * object, CFDictionaryRef userInfo) 
{
    NSDictionary *timePassDict = [  [NSDictionary alloc] 
                                    initWithContentsOfFile:@PLIST_PATH
                                ]?: [NSDictionary dictionary];

    isTweakEnabled              =       [[timePassDict valueForKey:@"isEnabled"]            ?:@NO boolValue];
    isReversed                  =       [[timePassDict valueForKey:@"isReversed"]           ?:@NO boolValue];
    shouldAlwaysShowTime        =       [[timePassDict valueForKey:@"shouldAlwaysShowTime"] ?:@YES boolValue];
    use24hFormat                =       [[timePassDict valueForKey:@"use24hFormat"]         ?:@YES boolValue];
    isSixDigitPasscode          =       [[timePassDict valueForKey:@"isSixDigitPasscode"]   ?:@YES boolValue];

    timeShift                   = (int) [[timePassDict valueForKey:@"timeShift"]            ?:@(0) intValue];
    lastTwoDigits               =       [[timePassDict valueForKey:@"lastTwoDigits"]        ?:@"00" copy];

    [timePassDict release];    
}

static void timePassCodeChanged(CFNotificationCenterRef center, void * observer, 
                                CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    [truePasscode release];
    truePasscode = nil;
}

uint64_t getState(char const * const name)
{
    int token;
    notify_register_check(name, &token);
    uint64_t state;
    notify_get_state(token, &state);
    notify_cancel(token);
    return state;
}

static void displayStatusChanged(CFNotificationCenterRef center, void * observer, 
                                    CFStringRef name, void const * object, CFDictionaryRef userInfo) 
{
    bool displayState = getState("com.apple.iokit.hid.displayStatus");
    NSLog(@"*g* display status is %s", displayState ? "ON" : "OFF");

    dispatch_async(dispatch_get_main_queue(), 
        ^{
            if (displayState && truePasscode && [truePasscode length]
                    && [gracePeriodEnds compare:[NSDate date]] == NSOrderedDescending
                    && [[%c(SBLockStateAggregator) sharedInstance] lockState] & LOCKSTATE_NEEDSAUTH_MASK)
            {
                [   [%c(SBLockScreenManager) sharedInstance] 
                    _attemptUnlockWithPasscode:truePasscode 
                    finishUIUnlock:NO
                ];
                NSLog(@"*g* Autounlock executed");
            }
        }
    );
}

static void lockstateChanged(CFNotificationCenterRef center, void * observer, 
                                CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    unsigned long long state = [[%c(SBLockStateAggregator) sharedInstance] lockState];
    NSLog(@"*g* Lock state is %llu: %s", 
            state, 
            state & LOCKSTATE_NEEDSAUTH_MASK 
                ? "LOCKED" : "UNLOCKED");

    if((state & LOCKSTATE_NEEDSAUTH_MASK) 
        && !(lastLockstate & LOCKSTATE_NEEDSAUTH_MASK))
        updateGracePeriod();

    lastLockstate = state;
}

%ctor 
{
	CFNotificationCenterAddObserver (   CFNotificationCenterGetDarwinNotifyCenter(), NULL, 
                                        timePassSettingsChanged,
                                        CFSTR("com.giorgioiavicoli.timepass/SettingsChanged"), NULL, 
                                        CFNotificationSuspensionBehaviorCoalesce
                                    );

    CFNotificationCenterAddObserver (   CFNotificationCenterGetDarwinNotifyCenter(), NULL, 
                                        timePassCodeChanged,
                                        CFSTR("com.giorgioiavicoli.timepass/CodeChanged"), NULL, 
                                        CFNotificationSuspensionBehaviorCoalesce
                                    );

	dlopen("/System/Library/PrivateFrameworks/SpringBoardUIServices.framework/SpringBoardUIServices", RTLD_LAZY);

    CFNotificationCenterAddObserver (   CFNotificationCenterGetDarwinNotifyCenter(), NULL, 
                                        displayStatusChanged, 
                                        CFSTR("com.apple.iokit.hid.displayStatus"), NULL, 
                                        0 // Does not delete item from CFNC queue (?)
                                    );

    CFNotificationCenterAddObserver (   CFNotificationCenterGetDarwinNotifyCenter(), NULL, 
                                        lockstateChanged, 
                                        CFSTR("com.apple.springboard.lockstate"), NULL, 
                                        0
                                    );

    timePassSettingsChanged(NULL, NULL, CFSTR("com.giorgioiavicoli.timepass/SettingsChanged"), NULL, NULL);
}