#import <Foundation/Foundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <notify.h>

#include "crypto.h"

static BOOL isTweakEnabled;
static BOOL savePasscode;
static BOOL use24hFormat;

static BOOL isSixDigitPasscode;
static BOOL useMagicPasscode;

static BOOL useGracePeriod;
static BOOL useGracePeriodOnWiFi;
static BOOL useGracePeriodOnBT;
static BOOL headphonesAutoUnlock;

static BOOL showLastUnlock;
static BOOL dismissLS;
static BOOL dismissLSWithMedia;

static BOOL disableInSOSMode;
static BOOL disableDuringTime;
static BOOL disableBioDuringTime;
static BOOL disableAlert;

static BOOL NCHasContent;
static BOOL unlockedWithTimeout;
static BOOL wasUsingHeadphones;
static BOOL isInSOSMode;
static BOOL lastLockedState;

static int  gracePeriod;
static int  gracePeriodOnWiFi;
static int  gracePeriodOnBT;
static int  digitsGracePeriod;
static int  timeShift;

#include "PassByHelper.h"
static struct Digits first, second, last;
static struct Time disableFromTime, disableToTime;

static NSDate   *   disableFromDate     = nil;
static NSDate   *   disableToDate       = nil;

static NSDate   *   gracePeriodEnds     = nil;
static NSDate   *   gracePeriodWiFiEnds = nil;
static NSDate   *   gracePeriodBTEnds   = nil;
static NSTimer  *   graceTimeoutTimer   = nil;

static NSArray  *   allowedSSIDs        = nil;
static NSArray  *   allowedBTs          = nil;


static NSString *   truePasscode        = nil;
static NSData   *   UUID                = nil;

static NSDate   *   currentDate         = nil;
static NSDate   *   lastUnlock          = nil;

#define PLIST_PATH      "/var/mobile/Library/Preferences/com.giorgioiavicoli.passby.plist"
#define WIFI_PLIST_PATH "/var/mobile/Library/Preferences/com.giorgioiavicoli.passbynets.plist"
#define BT_PLIST_PATH   "/var/mobile/Library/Preferences/com.giorgioiavicoli.passbybt.plist"

#define LOCKSTATE_NEEDSAUTH_MASK    0x02

BOOL isUsingHeadphones();
BOOL isUsingWiFi();
BOOL isUsingBT();

static void savePasscodeToFile()
{
    NSMutableDictionary * passByDict =
        [   [NSMutableDictionary alloc] 
            initWithContentsOfFile:@PLIST_PATH
        ]?: [NSMutableDictionary new];

    NSData * passcodeData =
        AES128Encrypt(
            [truePasscode 
                dataUsingEncoding:NSUTF8StringEncoding
            ], UUID
        );

    [passByDict 
        setObject:passcodeData
        forKey:@"passcode"
    ];
    [passByDict writeToFile:@(PLIST_PATH) atomically:YES];
    [passByDict release];
    [passcodeData release];
}

static void updateGracePeriods()
{
    [gracePeriodEnds release];
    [gracePeriodWiFiEnds release];
    [gracePeriodBTEnds release];

    gracePeriodEnds = 
        useGracePeriod 
            ? (gracePeriod
                ? [[[NSDate new] dateByAddingTimeInterval: gracePeriod] retain]
                : [[NSDate distantFuture] copy]
            ) : nil;

    gracePeriodWiFiEnds = 
        useGracePeriodOnWiFi && isUsingWiFi()
            ? (gracePeriodOnWiFi 
                ? [[[NSDate new] dateByAddingTimeInterval: gracePeriodOnWiFi] retain]
                : [[NSDate distantFuture] copy]
            ) : nil;
    
    gracePeriodBTEnds = 
        useGracePeriodOnBT && isUsingBT()
            ? (gracePeriodOnBT
                ? [[[NSDate new] dateByAddingTimeInterval: gracePeriodOnBT] retain]
                : [[NSDate distantFuture] copy]
            ) : nil;
    
    wasUsingHeadphones = isUsingHeadphones();
}

void refreshDisabledInterval()
{
    [currentDate        release];
    [disableFromDate    release];
    [disableToDate      release];

    currentDate = [NSDate new];

    disableFromDate = 
        [   [NSCalendar currentCalendar] 
            dateBySettingHour:  disableFromTime.hours
            minute:             disableFromTime.minutes
            second:0
            ofDate:currentDate
            options:NSCalendarMatchFirst
        ];
    disableToDate = 
        [   [NSCalendar currentCalendar] 
            dateBySettingHour:  disableToTime.hours
            minute:             disableToTime.minutes
            second:0
            ofDate:currentDate
            options:NSCalendarMatchFirst
        ];
}


static BOOL isTemporaryDisabled()
{
    if (!disableDuringTime)
        return NO;

    if (
    ![  [NSCalendar currentCalendar] 
        isDate:[NSDate date] 
        inSameDayAsDate:currentDate
    ]) {
        refreshDisabledInterval();
    }

    return 
        [disableFromDate compare:disableToDate] == NSOrderedAscending
            ? [disableFromDate compare:currentDate] == NSOrderedAscending
                && [currentDate compare:disableToDate] == NSOrderedAscending
            : [disableFromDate compare:currentDate] == NSOrderedAscending
                || [currentDate compare:disableToDate] == NSOrderedAscending
        ;
}

BOOL passcodeChecksOut(NSString * passcode) 
{
    return first.eval(&first, [passcode characterAtIndex:0], [passcode characterAtIndex:1])
        && second.eval(&second, [passcode characterAtIndex:2], [passcode characterAtIndex:3])
        && (!isSixDigitPasscode 
            || last.eval(&last, [passcode characterAtIndex:4], [passcode characterAtIndex:5])
        );
}

BOOL checkAttemptedUnlock(NSString * passcode)
{
    return passcode && truePasscode
    && useMagicPasscode 
    && !isInSOSMode 
    && !isTemporaryDisabled()
    && [passcode length] == (isSixDigitPasscode ? 6 : 4)
    && [truePasscode length] == (isSixDigitPasscode ? 6 : 4)
    && ![truePasscode isEqualToString:passcode]
    && passcodeChecksOut(passcode);
}


@class SBLockScreenViewControllerBase; //Forward declaration

@interface SBLockScreenManager : NSObject
@property(readonly) BOOL isUILocked;
+ (id)sharedInstance;
//- (BOOL)attemptUnlockWithPasscode:(NSString *)passcode;
- (void)attemptUnlockWithPasscode:(NSString *)passcode completion:(/*^block*/id)arg2 ;

- (BOOL)_attemptUnlockWithPasscode:(NSString *)passcode finishUIUnlock:(BOOL)arg2;
- (BOOL)_attemptUnlockWithPasscode:(NSString *)passcode mesa:(BOOL)arg2 finishUIUnlock:(BOOL)arg3 ;
- (BOOL)_attemptUnlockWithPasscode:(NSString *)passcode mesa:(BOOL)arg2 finishUIUnlock:(BOOL)arg3 completion:(/*^block*/id)arg4 ;

- (SBLockScreenViewControllerBase *) lockScreenViewController;
@end


static void unlockedWithPrimary(NSString * passcode)
{
    if (passcode 
    && [passcode length] == (isSixDigitPasscode ? 6 : 4)
    ) {
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                isInSOSMode = NO;
                if (!truePasscode 
                || [truePasscode length] != (isSixDigitPasscode ? 6 : 4)
                || ![truePasscode isEqualToString:passcode]
                ) {
                    [truePasscode release];
                    truePasscode = [passcode copy];
                    if (savePasscode)
                        savePasscodeToFile();
                        
                    if (!disableAlert) {
                        UIAlertView *alert =    
                            [   [UIAlertView alloc]
                                initWithTitle:@"PassBy"
                                message:@"PassBy enabled!"
                                delegate:nil 
                                cancelButtonTitle:@"OK" 
                                otherButtonTitles:nil
                            ];
                        [alert show];
                        [alert release];
                    }
                }
            }
        );
    };
}

@interface SpringBoard
+ (id)sharedApplication;
- (void)_simulateLockButtonPress;
@end

static void unlockedWithSecondary()
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            if (first.isGracePeriod
            || second.isGracePeriod
            || (isSixDigitPasscode && last.isGracePeriod)
            ) {
                unlockedWithTimeout = YES;
                if (digitsGracePeriod) {
                    graceTimeoutTimer = 
                        [NSTimer 
                            scheduledTimerWithTimeInterval:digitsGracePeriod
                            repeats:NO
                            block:^(NSTimer *)
                            {
                                graceTimeoutTimer = nil;
                                [   [%c(SpringBoard) sharedApplication] 
                                    _simulateLockButtonPress
                                ];
                            }
                        ];
                }
            }
        }
    );
}

@interface SBLockStateAggregator : NSObject
+(id)sharedInstance;
-(unsigned long long)lockState;
@end

BOOL isDeviceLocked()
{
    return 
        [   [%c(SBLockStateAggregator) sharedInstance] 
            lockState
        ] & LOCKSTATE_NEEDSAUTH_MASK;
}


@interface SBFAuthenticationRequest : NSObject
- (NSData *)payload;
@end

@interface SBFUserAuthenticationController
- (void)processAuthenticationRequest:(SBFAuthenticationRequest *)arg1 responder:(id)arg2;
@end

%group iOS10
%hook SBFUserAuthenticationController
- (void)processAuthenticationRequest:(SBFAuthenticationRequest *)request responder:(id)arg2 
{   
    if (!isTweakEnabled)
        return %orig;
    
    NSString * passcode = 
        [   [[NSString alloc] retain]
            initWithData:[request payload]
            encoding:NSASCIIStringEncoding
        ];
    
    SBLockScreenManager * SBLSManager = [%c(SBLockScreenManager) sharedInstance];

    if (checkAttemptedUnlock(passcode)) {
        [SBLSManager _attemptUnlockWithPasscode:truePasscode finishUIUnlock: YES];
        if (![SBLSManager isUILocked]) 
            unlockedWithSecondary();
    } else {
        %orig;
        if (![SBLSManager isUILocked])
            unlockedWithPrimary(passcode);
    }

    [passcode release];
}
%end
%end


%group iOS11
%hook SBLockScreenManager
- (BOOL)_attemptUnlockWithPasscode:
        (NSString *)passcode mesa:(BOOL)didUseBiometric 
        finishUIUnlock:(BOOL)arg3 
        completion:(/*^block*/id)arg4 
{
    if (!isTweakEnabled || didUseBiometric)
        return %orig;

    BOOL ret;
    if (checkAttemptedUnlock(passcode)) {
        ret = %orig(truePasscode, didUseBiometric, arg3, arg4);
        if (!isDeviceLocked()) 
            unlockedWithSecondary();
    } else {
        ret = %orig;
        if (!isDeviceLocked())
            unlockedWithPrimary(passcode);
    }
    return ret;
}
%end
%end
/*
%hook SBLockScreenManager
- (void)attemptUnlockWithPasscode:(NSString*)passcode completion:(id)arg2 
{
    if (!isTweakEnabled)
        return %orig;

    if (checkAttemptedUnlock(passcode)) {
        %orig(truePasscode, arg2);
        if (!isDeviceLocked()) 
            unlockedWithSecondary();
    } else {
        %orig;
        if (!isDeviceLocked())
            unlockedWithPrimary(passcode);
    }
}
%end
*/


@interface SBUIPasscodeLockViewWithKeypad
- (UILabel *)statusTitleView;
@end

%hook SBUIPasscodeLockViewWithKeypad
- (UILabel *)statusTitleView
{
    if (isTweakEnabled) {
        UILabel * label = MSHookIvar<UILabel *>(self, "_statusTitleView");

        if (!truePasscode || [truePasscode length] != (isSixDigitPasscode ? 6 : 4)) {
            label.text = @"PassBy requires passcode";
        } else if (showLastUnlock && lastUnlock) {
            NSMutableString * str = [NSMutableString stringWithString:@"Last unlock was at "];
            [str appendString:stringFromDateAndFormat(lastUnlock, use24hFormat ? @"H:mm:ss" : @"h:mm:ss a")];
            label.text = str;
        }

        return label;
    }
    return %orig;
}
%end


@interface SBSOSLockGestureObserver
- (void)pressSequenceRecognizerDidCompleteSequence:(id)arg1 ;
@end

%hook SBSOSLockGestureObserver
- (void)pressSequenceRecognizerDidCompleteSequence:(id)arg1
{
    %orig;
    isInSOSMode = disableInSOSMode;
}
%end

@interface SBLockScreenBiometricAuthenticationCoordinator
- (BOOL)isUnlockingDisabled;
@end

%hook SBLockScreenBiometricAuthenticationCoordinator
- (BOOL)isUnlockingDisabled
{
    return isTweakEnabled && disableBioDuringTime
        ? (isTemporaryDisabled() || %orig)
        : %orig;
}
%end


@interface VolumeControl
+ (id)sharedVolumeControl;
- (BOOL)headphonesPresent;
@end

BOOL isUsingHeadphones()
{
    return [[%c(VolumeControl) sharedVolumeControl] headphonesPresent];
}

BOOL isUsingWiFi()
{
    if (!useGracePeriodOnWiFi)
        return NO;

    NSString * SSID = ((NSDictionary *)CNCopyCurrentNetworkInfo(CFSTR("en0"))) [@"SSID"];
    return 
        SSID && [SSID length]
        && allowedSSIDs 
        && [allowedSSIDs containsObject:SHA1(SSID)];
}

@interface BluetoothDevice : NSObject
-(NSString *)name;
-(NSString*)address;
@end


@interface BluetoothManager : NSObject
+(id)sharedInstance;
-(id)connectedDevices;
@end

BOOL isUsingBT()
{
    if (useGracePeriodOnBT && allowedBTs) {
        NSArray * connectedDevices = 
            [[BluetoothManager sharedInstance] connectedDevices];
        if ([connectedDevices count]) {
            for (BluetoothDevice * bluetoothDevice in connectedDevices) {
                NSString * deviceName = [bluetoothDevice name];
                if (deviceName && [deviceName length]
                && [allowedBTs containsObject:SHA1(deviceName)])
                    return YES;
    }   }   }
    return NO;
}



BOOL isInGrace()
{
    if (isTemporaryDisabled())
        return NO;
    
    if (gracePeriodEnds 
    && [gracePeriodEnds compare:[NSDate date]] == NSOrderedDescending)
        return YES;

    if (gracePeriodWiFiEnds 
    && [gracePeriodWiFiEnds compare:[NSDate date]] == NSOrderedDescending
    && isUsingWiFi()
    ) {
        return YES;
    } else {
        [gracePeriodWiFiEnds release];
        gracePeriodWiFiEnds = nil;
    }

    if (gracePeriodBTEnds 
    && [gracePeriodBTEnds compare:[NSDate date]] == NSOrderedDescending 
    && isUsingBT()
    ) {
        return YES;
    } else {
        [gracePeriodBTEnds release];
        gracePeriodBTEnds = nil;
    }

    if (headphonesAutoUnlock)
        return (wasUsingHeadphones = wasUsingHeadphones && isUsingHeadphones());

    return NO;
}


%group iOS11
@interface NCNotificationCombinedListViewController
- (BOOL)hasContent;
@end
%hook NCNotificationCombinedListViewController
- (void)viewWillLayoutSubviews
{
	%orig;
	NCHasContent = [self hasContent];
}
%end
%end

%group iOS10
@interface NCNotificationListViewController
- (BOOL)hasContent;
@end
%hook NCNotificationListViewController
- (void)viewWillLayoutSubviews
{
	%orig;
	NCHasContent = [self hasContent];
}
%end
%end


@interface SBLockScreenViewControllerBase
-(BOOL)isShowingMediaControls;
@end

@interface SBAssistantController
+(BOOL) isAssistantVisible;
@end

uint64_t getState(char const * const name)
{
    int token;
    notify_register_check(name, &token);
    uint64_t state;
    notify_get_state(token, &state);
    notify_cancel(token);
    return state;
}


static void displayStatusChanged(   
    CFNotificationCenterRef center, void * observer, 
    CFStringRef name, void const * object, CFDictionaryRef userInfo) 
{
    if (isTweakEnabled && !isInSOSMode) {
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                if (getState("com.apple.iokit.hid.displayStatus")
                && truePasscode && [truePasscode length]
                && isInGrace()
                && ([[%c(SBLockStateAggregator) sharedInstance] lockState] & LOCKSTATE_NEEDSAUTH_MASK)
                ) {
                    [   [%c(SBLockScreenManager) sharedInstance] 
                        _attemptUnlockWithPasscode:truePasscode 
                        finishUIUnlock: dismissLS 
                                        && !NCHasContent 
                                        && (dismissLSWithMedia || ![[   [%c(SBLockScreenManager) sharedInstance] 
                                                                        lockScreenViewController
                                                                    ] isShowingMediaControls])
                                        && ![%c(SBAssistantController) isAssistantVisible]
                    ];
                }
            }
        );
    }
}

static void lockstateChanged(   
    CFNotificationCenterRef center, void * observer, 
    CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    if (isTweakEnabled)
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                BOOL lockedState = isDeviceLocked();

                if (lockedState) {
                    if (!lastLockedState) {
                        if (graceTimeoutTimer) {
                            [graceTimeoutTimer invalidate];
                            graceTimeoutTimer = nil;
                        } else if (unlockedWithTimeout) {
                            wasUsingHeadphones = NO;
                        } else {
                            updateGracePeriods();
                        }
                        unlockedWithTimeout = NO;
                    }
                } else if (lastLockedState) {
                    [lastUnlock release];
                    lastUnlock = [NSDate new];
                }

                lastLockedState = lockedState;
            }
        );
}




static void passBySettingsChanged(
    CFNotificationCenterRef center, void * observer, 
    CFStringRef name, void const * object, CFDictionaryRef userInfo) 
{
    NSDictionary * passByDict =   [   [NSDictionary alloc] 
                                        initWithContentsOfFile:@PLIST_PATH
                                    ]?: [NSDictionary new];

    isTweakEnabled          =   [[passByDict valueForKey:@"isEnabled"]              ?:@NO boolValue];
    savePasscode            =   [[passByDict valueForKey:@"savePasscode"]           ?:@NO boolValue];
    isSixDigitPasscode      =   [[passByDict valueForKey:@"isSixDigitPasscode"]     ?:@YES boolValue];
    showLastUnlock          =   [[passByDict valueForKey:@"showLastUnlock"]         ?:@NO boolValue];
    use24hFormat            =   [[passByDict valueForKey:@"use24hFormat"]           ?:@YES boolValue];

    int unit;
    useGracePeriod          =   [[passByDict valueForKey:@"useGracePeriod"]         ?:@NO boolValue];
    gracePeriod             =   [[passByDict valueForKey:@"gracePeriod"]            ?:@(0) intValue];
    gracePeriodUnit         =   [[passByDict valueForKey:@"gracePeriodUnit"]        ?:@(1) intValue];
    gracePeriod            *=   gracePeriodUnit;

    useGracePeriodOnWiFi    =   [[passByDict valueForKey:@"useGracePeriodOnWiFi"]   ?:@NO boolValue];
    gracePeriodOnWiFi       =   [[passByDict valueForKey:@"gracePeriodOnWiFi"]      ?:@(0) intValue];
    gracePeriodUnit         =   [[passByDict valueForKey:@"gracePeriodUnitOnWiFi"]  ?:@(1) intValue];
    gracePeriodOnWiFi      *=   gracePeriodUnit;


    useGracePeriodOnBT      =   [[passByDict valueForKey:@"useGracePeriodOnBT"]     ?:@NO boolValue];
    gracePeriodOnBT         =   [[passByDict valueForKey:@"gracePeriodOnBT"]        ?:@(0) intValue];
    gracePeriodUnit         =   [[passByDict valueForKey:@"gracePeriodUnitOnBT"]    ?:@(1) intValue];
    gracePeriodOnBT        *=   gracePeriodUnit;

    headphonesAutoUnlock    =   [[passByDict valueForKey:@"headphonesAutoUnlock"]   ?:@NO boolValue];

    dismissLS               =   [[passByDict valueForKey:@"dismissLS"]              ?:@NO boolValue];
    dismissLSWithMedia      =   [[passByDict valueForKey:@"dismissLSWithMedia"]     ?:@NO boolValue];

    useMagicPasscode        =   [[passByDict valueForKey:@"useMagicPasscode"]       ?:@NO boolValue];
    timeShift               =   [[passByDict valueForKey:@"timeShift"]              ?:@(0) intValue];

    disableInSOSMode        =   [[passByDict valueForKey:@"disableInSOSMode"]       ?:@YES boolValue];
    disableDuringTime       =   [[passByDict valueForKey:@"disableDuringTime"]      ?:@NO boolValue];
    disableBioDuringTime    =   [[passByDict valueForKey:@"disableBioDuringTime"]   ?:@NO boolValue];
    disableAlert            =   [[passByDict valueForKey:@"disableAlert"]           ?:@NO boolValue];

    disableDuringTime = 
        disableDuringTime
        && parseTime(&disableFromTime, [passByDict valueForKey:@"disableFromTime"])
        && parseTime(&disableToTime,   [passByDict valueForKey:@"disableToTime"]);

    if (disableDuringTime)
        refreshDisabledInterval();

    parseDigitsConfiguration(&first,
        [passByDict valueForKey:@"firstTwoCustomDigits"]    ?:@"00",
        [[passByDict valueForKey:@"firstTwo"]               ?:@(7) intValue],
        [[passByDict valueForKey:@"firstTwoReversed"]       ?:@NO boolValue]
    );
    parseDigitsConfiguration(&second,
        [passByDict valueForKey:@"secondTwoCustomDigits"]   ?:@"00",
        [[passByDict valueForKey:@"secondTwo"]              ?:@(7) intValue],
        [[passByDict valueForKey:@"secondTwoReversed"]      ?:@NO boolValue]
    );
    parseDigitsConfiguration(&last,
        [passByDict valueForKey:@"lastTwoCustomDigits"]     ?:@"00",
        [[passByDict valueForKey:@"lastTwo"]                ?:@(7) intValue],
        [[passByDict valueForKey:@"lastTwoReversed"]        ?:@NO boolValue]
    );

    if ([[passByDict valueForKey:@"timeShiftDirection"] ?:@"+" characterAtIndex:0] == '-')
        timeShift = -timeShift;

    NSData * passcodeData = [passByDict valueForKey:@"passcode"];

    if (passcodeData && [passcodeData length]) {
        truePasscode = 
            [   [NSString alloc] 
                initWithData:AES128Decrypt(passcodeData, UUID)
                encoding:NSUTF8StringEncoding
            ];
    } else if (savePasscode && truePasscode 
    && [truePasscode length] == (isSixDigitPasscode ? 4 : 6)
    ) {
        savePasscodeToFile();
    }

    [passByDict release];    

    [gracePeriodEnds        release];
    gracePeriodEnds         = nil;
    [gracePeriodWiFiEnds    release];
    gracePeriodWiFiEnds     = nil;
    [gracePeriodBTEnds      release];
    gracePeriodBTEnds       = nil;
}

static void passByWiFiListChanged(
    CFNotificationCenterRef center, void * observer, 
    CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    NSDictionary * WiFiListDict =   [   [NSDictionary alloc] 
                                        initWithContentsOfFile:@WIFI_PLIST_PATH
                                    ]?: [NSDictionary new];

    NSMutableArray * WiFiListArr = [[NSMutableArray alloc] initWithCapacity:[WiFiListDict count]];

    for(NSString * key in [WiFiListDict keyEnumerator])
        if ([[WiFiListDict valueForKey:key] boolValue])
            [WiFiListArr addObject:[key copy]];
    
    [WiFiListDict release];
    [allowedSSIDs release];
    allowedSSIDs = [[NSArray alloc] initWithArray:WiFiListArr copyItems:NO];
    [WiFiListArr release];
}

static void passByBTListChanged(
    CFNotificationCenterRef center, void * observer, 
    CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    NSDictionary * BTListDict =   
        [   [NSDictionary alloc] 
            initWithContentsOfFile:@BT_PLIST_PATH
        ]?: [NSDictionary new];

    NSMutableArray * BTListArr = 
        [   [NSMutableArray alloc] 
            initWithCapacity:[BTListDict count]
        ];

    for(NSString * key in [BTListDict keyEnumerator])
        if ([[BTListDict valueForKey:key] boolValue])
            [BTListArr addObject:[key copy]];
    
    [BTListDict release];
    [allowedBTs release];
    allowedBTs = [[NSArray alloc] initWithArray:BTListArr copyItems:NO];
    [BTListArr release];
}


static void setDarwinNCObservers()
{
    CFNotificationCenterAddObserver (   CFNotificationCenterGetDarwinNotifyCenter(), NULL, 
                                        passBySettingsChanged,
                                        CFSTR("com.giorgioiavicoli.passby/reload"), NULL, 
                                        CFNotificationSuspensionBehaviorCoalesce
                                    );

    CFNotificationCenterAddObserver (   CFNotificationCenterGetDarwinNotifyCenter(), NULL, 
                                        passByWiFiListChanged,
                                        CFSTR("com.giorgioiavicoli.passby/wifi"), NULL, 
                                        CFNotificationSuspensionBehaviorCoalesce
                                    );
                                    
    CFNotificationCenterAddObserver (   CFNotificationCenterGetDarwinNotifyCenter(), NULL, 
                                        passByBTListChanged,
                                        CFSTR("com.giorgioiavicoli.passby/bt"), NULL, 
                                        CFNotificationSuspensionBehaviorCoalesce
                                    );

	dlopen("/System/Library/PrivateFrameworks/SpringBoardUIServices.framework/SpringBoardUIServices", RTLD_LAZY);
	dlopen("/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework/UserNotificationsUIKit", RTLD_LAZY);

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
}

static void setUUID()
{
    unsigned char * buffer = (unsigned char *) malloc(16);
    [   [[UIDevice currentDevice] identifierForVendor] 
        getUUIDBytes:buffer
    ];
    UUID = [    [NSData alloc] 
                initWithBytes:buffer length:16
    ];
    free(buffer);
}

%ctor 
{
    %init;
    if (kCFCoreFoundationVersionNumber >= 1443.00)
        %init(iOS11)
    else
        %init(iOS10)

    setDarwinNCObservers();
    setUUID();

    passBySettingsChanged(NULL, NULL, NULL, NULL, NULL);
    passByWiFiListChanged(NULL, NULL, NULL, NULL, NULL);

    unlockedWithTimeout = NO;
    wasUsingHeadphones  = NO;
    isInSOSMode         = NO;
    lastLockedState     = YES;
}