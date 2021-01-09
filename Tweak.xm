#import <Foundation/Foundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <UIKit/UIKit.h>

#import <dlfcn.h>
#import <notify.h>
#import <objc/runtime.h>

#include "crypto.h"


static BOOL isTweakEnabled;
static BOOL savePasscode;
static BOOL use24hFormat;
static BOOL showLastUnlock;

static BOOL useGracePeriod;
static BOOL useGracePeriodOnWiFi;
static BOOL useGracePeriodOnBT;
static BOOL allowBTGPWhileLocked;
static BOOL allowWiFiGPWhileLocked;
static BOOL headphonesAutoUnlock;
static BOOL watchAutoUnlock;

static BOOL useMagicPasscode;

static BOOL dismissLS;
static BOOL dismissLSWithMedia;

static BOOL disableInSOSMode;
static BOOL disableDuringTime;
static BOOL disableBioDuringTime;
static BOOL keepDisabledAfterTime;
static BOOL disableAlert;

static BOOL NCHasContent;
static BOOL unlockedWithTimeout;
static BOOL wasUsingHeadphones;
static BOOL isInSOSMode;
static BOOL isKeptDisabled;
static BOOL isManuallyDisabled;
static BOOL isDisabledUntilNext;
static BOOL lastLockedState;

static int  gracePeriod;
static int  gracePeriodOnWiFi;
static int  gracePeriodOnBT;
static int  passcodeLength;
static int  digitsGracePeriod;
static int  timeShift;

#include "PassByDigitsHelper.h"
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

static NSDate   *   currentDay          = nil;
static NSDate   *   lastUnlock          = nil;

static NSObject *   WiFiGracePeriodSyncObj;
static NSObject *   BTGracePeriodSyncObj;
static NSObject *   ManuallyDisabledSyncObj;

#define PLIST_PATH      "/var/mobile/Library/Preferences/com.giorgioiavicoli.passby.plist"
#define WIFI_PLIST_PATH "/var/mobile/Library/Preferences/com.giorgioiavicoli.passbynets.plist"
#define BT_PLIST_PATH   "/var/mobile/Library/Preferences/com.giorgioiavicoli.passbybt.plist"
#define GP_PLIST_PATH   "/var/mobile/Library/Preferences/com.giorgioiavicoli.passbygp.plist"

#if DEBUG
#   define PBLog(...) NSLog(@"*g* %s:%d: %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__])
#else
#   define PBLog(...)
#endif

#define LOCKSTATE_NEEDSAUTH_MASK    0x02

static const unsigned long PASSBY_AUTOUNLOCK_DELAY_NSECS = 200 * 1000;

static BOOL isUsingWiFi();
static BOOL isUsingBT();
static BOOL isUsingHeadphones();
static BOOL isUsingWatch();

#include "PassByGracePeriodHelper.h"

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
}


@interface SpringBoard : UIApplication
+ (id)  sharedApplication;
- (void)_simulateLockButtonPress;
@end

static void unlockedWithPrimary(NSString * passcode)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            isInSOSMode = NO;
            if (!truePasscode || ![truePasscode isEqualToString:passcode]) {
                [truePasscode release];
                truePasscode = [passcode copy];
                if (savePasscode) {
                    savePasscodeToFile();
                }
                if (!disableAlert) {
                    dispatch_async(dispatch_get_main_queue(),
                        ^{
                            UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:@"PassBy Enabled"
                                message:@"PassBy is now enabled"
                                preferredStyle:UIAlertControllerStyleAlert];
                            
                            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction * action) {}];
                            
                            [alert addAction:defaultAction];
                            [[[SpringBoard sharedApplication] keyWindow].rootViewController
                                presentViewController:alert animated:YES completion:nil];
                        }
                    );
                }
            }
        }
    );
}


static void unlockedWithSecondary()
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            if (first.isGracePeriod
            || second.isGracePeriod
            || (passcodeLength == 6 && last.isGracePeriod)
            ) {
                unlockedWithTimeout = YES;
                if (digitsGracePeriod) {
                    if (kCFCoreFoundationVersionNumber >= 1348.00) {
                        NSLog(@"*g* digitsGracePeriod: %d", digitsGracePeriod);
                        if (graceTimeoutTimer) {
                            [graceTimeoutTimer invalidate];
                            [graceTimeoutTimer release];
                        }
                        dispatch_async(dispatch_get_main_queue(),
                            ^{
                                graceTimeoutTimer = [
                                    [NSTimer
                                        scheduledTimerWithTimeInterval:digitsGracePeriod
                                        repeats:NO
                                        block:^(NSTimer *)
                                        {
                                            [graceTimeoutTimer invalidate];
                                            graceTimeoutTimer = nil;
                                            [[SpringBoard sharedApplication] _simulateLockButtonPress];
                                        }
                                    ] retain
                                ];
                            }
                        );
                    } else {
                        // ToDo: move to settigns
                        dispatch_async(dispatch_get_main_queue(),
                            ^{
                                UIAlertController* alert = [UIAlertController
                                    alertControllerWithTitle:@"PassBy"
                                    message:@"Timeout not supported below iOS 10"
                                    preferredStyle:UIAlertControllerStyleAlert];
                                
                                UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action) {}];
                                
                                [alert addAction:defaultAction];
                                [[[SpringBoard sharedApplication] keyWindow].rootViewController
                                    presentViewController:alert animated:YES completion:nil];
                            }
                        );
                    }
                }
            }
        }
    );
}

@interface SBLockStateAggregator : NSObject
+ (id)sharedInstance;
- (unsigned long long)lockState;
@end

BOOL isDeviceLocked()
{
    return
        [   [SBLockStateAggregator
                sharedInstance
            ] lockState
        ] & LOCKSTATE_NEEDSAUTH_MASK;
}


static BOOL passcodeChecksOut(NSString * passcode)
{
    return first.eval(&first, [passcode characterAtIndex:0], [passcode characterAtIndex:1])
        && second.eval(&second, [passcode characterAtIndex:2], [passcode characterAtIndex:3])
        &&  (passcodeLength == 4
            || last.eval(&last, [passcode characterAtIndex:4], [passcode characterAtIndex:5])
            );
}

static BOOL checkAttemptedUnlock(NSString * passcode)
{
    @synchronized(ManuallyDisabledSyncObj) {
        return useMagicPasscode
        && truePasscode
        && [truePasscode length]
        && [passcode length] == passcodeLength
        && ![passcode isEqualToString:truePasscode]
        && !isInSOSMode
        && !isManuallyDisabled
        && !isDisabledUntilNext
        && !isTemporaryDisabled()
        && passcodeChecksOut(passcode);
    }
}

//Forward declarations
@class SBLockScreenViewControllerBase, CSCoverSheetViewController;

@interface SBLockScreenManager : NSObject
@property(readonly) BOOL isUILocked;
+ (id)  sharedInstance;

- (BOOL)attemptUnlockWithPasscode:(NSString *)passcode;
//- (void)attemptUnlockWithPasscode:(NSString *)passcode completion:(/*^block*/id)arg2 ;

- (BOOL)_attemptUnlockWithPasscode:(NSString *)passcode finishUIUnlock:(BOOL)arg2;
//- (BOOL)_attemptUnlockWithPasscode:(NSString *)passcode mesa:(BOOL)arg2 finishUIUnlock:(BOOL)arg3 ;
- (BOOL)_attemptUnlockWithPasscode:(NSString *)passcode mesa:(BOOL)arg2 finishUIUnlock:(BOOL)arg3 completion:(/*^block*/id)arg4 ;

- (SBLockScreenViewControllerBase *) lockScreenViewController;
- (CSCoverSheetViewController     *) coverSheetViewController;
@end

static void unlockDevice(BOOL finishUIUnlock)
{
    [   [SBLockScreenManager sharedInstance]
        _attemptUnlockWithPasscode:truePasscode
        finishUIUnlock: finishUIUnlock
    ];
}

@interface SBFAuthenticationRequest : NSObject
- (NSData *)payload;
@end

@interface SBFUserAuthenticationController
- (void)processAuthenticationRequest:(SBFAuthenticationRequest *)arg1 responder:(id)arg2;
@end

%group iOS9
%hook SBLockScreenManager
- (BOOL)attemptUnlockWithPasscode:(NSString *)passcode
{
    if (!isTweakEnabled || !passcode) {
        return %orig;
    }

    if (checkAttemptedUnlock(passcode)) {
        if (%orig(truePasscode)) {
            unlockedWithSecondary();
            return YES;
        }
    }

    if (%orig) {
        unlockedWithPrimary(passcode);
        return YES;
    }

    return NO;
}
%end
%end

%group iOS10
%hook SBFUserAuthenticationController
- (void)processAuthenticationRequest:(SBFAuthenticationRequest *)request responder:(id)arg2
{
    if (!isTweakEnabled)
        return %orig;

    NSString * passcode =
        [   [NSString alloc]
            initWithData:[request payload]
            encoding:NSASCIIStringEncoding
        ];

    if (passcode && [passcode length]) {
        SBLockScreenManager * SBLSManager = [SBLockScreenManager sharedInstance];

        if (checkAttemptedUnlock(passcode)
        && [SBLSManager _attemptUnlockWithPasscode:truePasscode finishUIUnlock: YES]
        ) {
            unlockedWithSecondary();
        } else {
            %orig;
            if (![SBLSManager isUILocked]) {
                unlockedWithPrimary(passcode);
            }
        }
    }

    [passcode release];
}
%end
%end

%group iOS11andAbove
%hook SBLockScreenManager
- (BOOL)_attemptUnlockWithPasscode  :(NSString *)passcode
                            mesa    :(BOOL)arg2
                    finishUIUnlock  :(BOOL)arg3
                        completion  :(/*^block*/id)arg4
{
    if (!isTweakEnabled || !passcode) {
        return %orig;
    }

    SBLockScreenManager * SBLSManager = [SBLockScreenManager sharedInstance];

    if (checkAttemptedUnlock(passcode)) {
        if (%orig(truePasscode, arg2, arg3, arg4) && ![SBLSManager isUILocked]) {
            unlockedWithSecondary();
            return YES;
        }
    }

    if (%orig && ![SBLSManager isUILocked]) {
        unlockedWithPrimary(passcode);
        return YES;
    }

    return NO;
}
%end
%end



@interface SBUIPasscodeLockViewWithKeypad
- (UILabel *)statusTitleView;
@end

%hook SBUIPasscodeLockViewWithKeypad
- (UILabel *)statusTitleView
{
    if (isTweakEnabled) {
        UILabel * label = MSHookIvar<UILabel *>(self, "_statusTitleView");

        if (!truePasscode || ![truePasscode length]) {
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




@interface SBWiFiManager : NSObject
+ (id)sharedInstance;
- (id)currentNetworkName;
@end

static BOOL isUsingWiFi()
{
    if (!useGracePeriodOnWiFi)
        return NO;

    if (kCFCoreFoundationVersionNumber > 1500.00) {
        SBWiFiManager * SBWFM = [SBWiFiManager sharedInstance];
        if (!SBWFM)
            return NO;
        
        NSString * SSID = [SBWFM currentNetworkName];
        return SSID
            && [SSID length]
            && allowedSSIDs
            && [allowedSSIDs containsObject:SHA1(SSID)];
    } else {
        NSDictionary * currentNetwork =
            (__bridge NSDictionary *)
            CNCopyCurrentNetworkInfo(CFSTR("en0"));
        if (!currentNetwork) {
            [currentNetwork release];
            return NO;
        }

        NSString * SSID = [currentNetwork objectForKey:@"SSID"];
        BOOL result =  SSID
            && [SSID length]
            && allowedSSIDs
            && [allowedSSIDs containsObject:SHA1(SSID)];
        [currentNetwork release];
        return result;
    }
}

typedef struct __WiFiDeviceClient*  WiFiDeviceClientRef;
typedef void (*WiFiLinkCallback_t)          (WiFiDeviceClientRef device, const void *object);
typedef void (*WiFiRegisterLinkCallback_t)  (WiFiDeviceClientRef, WiFiLinkCallback_t,const void *);
//ToDo Is this being erroneously called upon respring..?
//Otherwise why is it no ptreserving the grace period?
static void _WiFiLinkDidChange(WiFiDeviceClientRef, void const *)
{ if (allowWiFiGPWhileLocked) updateWiFiGracePeriod(); }



@interface BluetoothDevice : NSObject
- (NSString *)name;
- (NSString *)address;
@end

@interface BluetoothManager : NSObject
+ (id)  sharedInstance;
- (id)  connectedDevices;
- (void)_connectedStatusChanged;
@end

static BOOL isUsingBT()
{
    if (useGracePeriodOnBT && allowedBTs) {
        NSArray * connectedDevices =
            [[BluetoothManager sharedInstance] connectedDevices];
        if ([connectedDevices count]) {
            for (BluetoothDevice * bluetoothDevice in connectedDevices) {
                NSString * deviceName = [bluetoothDevice name];
                if (deviceName
                && [deviceName length]
                && [allowedBTs containsObject:SHA1(deviceName)])
                    return YES;
    }   }   }
    return NO;
}

%hook BluetoothManager
- (void)_connectedStatusChanged
{
    %orig;
    if (allowBTGPWhileLocked)
        updateBTGracePeriod();
}
%end


@interface VolumeControl
+ (id)  sharedVolumeControl;
- (BOOL)headphonesPresent;
@end

static BOOL isUsingHeadphones()
{
    return [[%c(VolumeControl) sharedVolumeControl] headphonesPresent];
}


@interface BCBatteryDeviceController : NSObject
+ (id)sharedInstance;
- (NSArray *)connectedDevices;
@end

@interface BCBatteryDevice : NSObject
@property(nonatomic) unsigned long long accessoryCategory;
@end

static BOOL isUsingWatch()
{
    BCBatteryDeviceController *batteryDeviceController = [BCBatteryDeviceController sharedInstance];
    if (!batteryDeviceController) {
        return false;
    }

    for (BCBatteryDevice *device in [batteryDeviceController connectedDevices]) {
        if ([device accessoryCategory] == 3) {
            return true;
        }
    }

    return false;
}





%group iOS11andAbove
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

%group iOS9
@interface SBLockScreenViewController
-(void)notificationListBecomingVisible:(BOOL)arg1 ;
@end
%hook SBLockScreenViewController
-(void)notificationListBecomingVisible:(BOOL)arg1
{
	%orig;
	NCHasContent = arg1;
}
%end
%end


@interface SBLockScreenViewControllerBase
- (BOOL)isShowingMediaControls;
@end

@interface CSCoverSheetViewController
- (BOOL)isShowingMediaControls;
@end

BOOL isLockScreenShowingMediaControls()
{
    if (kCFCoreFoundationVersionNumber >= 1665.15) { // iOS >= 13.0
        return [  [   [SBLockScreenManager
                    sharedInstance
                ] coverSheetViewController
            ] isShowingMediaControls
        ];
    } else {
        return [  [   [SBLockScreenManager
                    sharedInstance
                ] lockScreenViewController
            ] isShowingMediaControls
        ];
    }
}


@interface SBAssistantController
+ (BOOL) isAssistantVisible;
+ (BOOL) isVisible;
@end


BOOL isSiriVisible()
{
    if (kCFCoreFoundationVersionNumber >= 1665.15) { // iOS >= 13.0
        return [SBAssistantController isVisible];
    } else {
        return [SBAssistantController isAssistantVisible];
    }
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

static void displayStatusChanged(
    CFNotificationCenterRef center, void * observer,
    CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    if (isTweakEnabled && !isInSOSMode) {
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, PASSBY_AUTOUNLOCK_DELAY_NSECS),
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
            ^(void){
                dispatch_async(dispatch_get_main_queue(),
                    ^{
                        if (getState("com.apple.iokit.hid.displayStatus")
                        && truePasscode
                        && [truePasscode length]
                        && isInGrace()
                        && ([[SBLockStateAggregator sharedInstance] lockState] & LOCKSTATE_NEEDSAUTH_MASK)
                        ) {
                            unlockDevice(
                                dismissLS
                                && !NCHasContent
                                && (dismissLSWithMedia || !isLockScreenShowingMediaControls())
                                && !isSiriVisible()
                            );
                        }
                    }
                );
            }
        );
    }
}

static void lockstateChanged(
    CFNotificationCenterRef center, void * observer,
    CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    if (isTweakEnabled)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                BOOL lockedState = isDeviceLocked();

                if (lockedState) {
                    if (!lastLockedState) {
                        if (graceTimeoutTimer) {
                            [graceTimeoutTimer invalidate];
                            [graceTimeoutTimer release];
                            graceTimeoutTimer = nil;
                        } else if (unlockedWithTimeout) {
                            invalidateAllGracePeriods();
                        } else {
                            updateAllGracePeriods();
                        }

                        if (savePasscode)
                            saveAllGracePeriods();

                        unlockedWithTimeout = NO;
                    }
                } else if (lastLockedState) {
                    [lastUnlock release];
                    lastUnlock = [NSDate new];

                    isDisabledUntilNext = NO;

                    if (isKeptDisabled
                    && [disableToDate compare:[NSDate date]] == NSOrderedAscending
                    ) {
                        isKeptDisabled = NO;
                    }
                }

                lastLockedState = lockedState;
            }
        );
}




static void passBySettingsChanged(
    CFNotificationCenterRef center, void * observer,
    CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    NSDictionary * passByDict =
        [   [NSDictionary alloc]
            initWithContentsOfFile:@PLIST_PATH
        ]?: [NSDictionary new];

    isTweakEnabled          =   [[passByDict valueForKey:@"isEnabled"]              ?:@NO   boolValue];
    savePasscode            =   [[passByDict valueForKey:@"savePasscode"]           ?:@NO   boolValue];
    showLastUnlock          =   [[passByDict valueForKey:@"showLastUnlock"]         ?:@NO   boolValue];
    use24hFormat            =   [[passByDict valueForKey:@"use24hFormat"]           ?:@YES  boolValue];


    useGracePeriod          =   [[passByDict valueForKey:@"useGracePeriod"]         ?:@NO   boolValue];
    gracePeriod             =   [[passByDict valueForKey:@"gracePeriod"]            ?:@(0)  intValue];
    gracePeriod            *=   [[passByDict valueForKey:@"gracePeriodUnit"]        ?:@(1)  intValue];

    useGracePeriodOnWiFi    =   [[passByDict valueForKey:@"useGracePeriodOnWiFi"]   ?:@NO   boolValue];
    gracePeriodOnWiFi       =   [[passByDict valueForKey:@"gracePeriodOnWiFi"]      ?:@(0)  intValue];
    gracePeriodOnWiFi      *=   [[passByDict valueForKey:@"gracePeriodUnitOnWiFi"]  ?:@(1)  intValue];
    allowWiFiGPWhileLocked  =   [[passByDict valueForKey:@"allowWiFiGPWhileLocked"] ?:@NO   boolValue];

    useGracePeriodOnBT      =   [[passByDict valueForKey:@"useGracePeriodOnBT"]     ?:@NO   boolValue];
    gracePeriodOnBT         =   [[passByDict valueForKey:@"gracePeriodOnBT"]        ?:@(0)  intValue];
    gracePeriodOnBT        *=   [[passByDict valueForKey:@"gracePeriodUnitOnBT"]    ?:@(1)  intValue];
    allowBTGPWhileLocked    =   [[passByDict valueForKey:@"allowBTGPWhileLocked"]   ?:@NO   boolValue];


    headphonesAutoUnlock    =   [[passByDict valueForKey:@"headphonesAutoUnlock"]   ?:@NO   boolValue];
    watchAutoUnlock         =   [[passByDict valueForKey:@"watchAutoUnlock"]        ?:@NO   boolValue];

    dismissLS               =   [[passByDict valueForKey:@"dismissLS"]              ?:@NO   boolValue];
    dismissLSWithMedia      =   [[passByDict valueForKey:@"dismissLSWithMedia"]     ?:@NO   boolValue];

    useMagicPasscode        =   [[passByDict valueForKey:@"useMagicPasscode"]       ?:@NO   boolValue];
    passcodeLength          =   [[passByDict valueForKey:@"passcodeLength"]         ?:@(6)  intValue];
    timeShift               =   [[passByDict valueForKey:@"timeShift"]              ?:@(0)  intValue];

    disableInSOSMode        =   [[passByDict valueForKey:@"disableInSOSMode"]       ?:@YES  boolValue];
    disableDuringTime       =   [[passByDict valueForKey:@"disableDuringTime"]      ?:@NO   boolValue];
    disableBioDuringTime    =   [[passByDict valueForKey:@"disableBioDuringTime"]   ?:@NO   boolValue];
    keepDisabledAfterTime   =   [[passByDict valueForKey:@"keepDisabledAfterTime"]  ?:@NO   boolValue];
    disableAlert            =   [[passByDict valueForKey:@"disableAlert"]           ?:@NO   boolValue];

    disableDuringTime =
        disableDuringTime
        && parseTime(&disableFromTime, [passByDict valueForKey:@"disableFromTime"])
        && parseTime(&disableToTime,   [passByDict valueForKey:@"disableToTime"]);

    if (disableDuringTime)
        refreshDisabledInterval();

    parseDigitsConfiguration(&first,
        [passByDict valueForKey:@"firstTwoCustomDigits"]    ?:@"00",
        [[passByDict valueForKey:@"firstTwo"]               ?:@(7)  intValue],
        [[passByDict valueForKey:@"firstTwoReversed"]       ?:@NO   boolValue]
    );
    parseDigitsConfiguration(&second,
        [passByDict valueForKey:@"secondTwoCustomDigits"]   ?:@"00",
        [[passByDict valueForKey:@"secondTwo"]              ?:@(7)  intValue],
        [[passByDict valueForKey:@"secondTwoReversed"]      ?:@NO   boolValue]
    );
    parseDigitsConfiguration(&last,
        [passByDict valueForKey:@"lastTwoCustomDigits"]     ?:@"00",
        [[passByDict valueForKey:@"lastTwo"]                ?:@(7)  intValue],
        [[passByDict valueForKey:@"lastTwoReversed"]        ?:@NO   boolValue]
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
    } else if (savePasscode
    && truePasscode
    && [truePasscode length] == passcodeLength
    ) {
        savePasscodeToFile();
    }

    [passByDict release];

    [gracePeriodEnds        release];
    gracePeriodEnds         = nil;

    @synchronized(WiFiGracePeriodSyncObj) {
        [gracePeriodWiFiEnds    release];
        gracePeriodWiFiEnds     = nil;
    }

    @synchronized(BTGracePeriodSyncObj) {
        [gracePeriodBTEnds      release];
        gracePeriodBTEnds       = nil;
    }
}

static void passByWiFiListChanged(
    CFNotificationCenterRef center, void * observer,
    CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    NSDictionary * WiFiListDict =
        [   [NSDictionary alloc]
            initWithContentsOfFile:@WIFI_PLIST_PATH
        ]?: [NSDictionary new];

    NSMutableArray * WiFiListArr =
        [   [NSMutableArray alloc]
            initWithCapacity:[WiFiListDict count]
        ];

    for(NSString * key in [WiFiListDict keyEnumerator])
        if ([[WiFiListDict valueForKey:key] boolValue])
            [WiFiListArr addObject:[key copy]];

    [allowedSSIDs release];
    allowedSSIDs = [[NSArray alloc] initWithArray:WiFiListArr copyItems:YES];
    [WiFiListDict release];
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

    [allowedBTs release];
    allowedBTs = [[NSArray alloc] initWithArray:BTListArr copyItems:YES];
    [BTListDict release];
    [BTListArr release];
}

static void flipSwitchOn(
    CFNotificationCenterRef center, void * observer,
    CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    @synchronized(ManuallyDisabledSyncObj) {
        isManuallyDisabled = NO;
    }
}

static void flipSwitchOff(
    CFNotificationCenterRef center, void * observer,
    CFStringRef name, void const * object, CFDictionaryRef userInfo)
{
    @synchronized(ManuallyDisabledSyncObj) {
        isManuallyDisabled = YES;
    }
}


static void setDarwinNCObserver(CFNotificationCallback callback, CFStringRef name)
{
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, callback, name, NULL, (CFNotificationSuspensionBehavior) NULL
    );
}

static void getUUID()
{
    unsigned char * buffer = (unsigned char *) malloc(16);
    [   [[UIDevice currentDevice] identifierForVendor]
        getUUIDBytes:buffer
    ];
    UUID = [NSData dataWithBytesNoCopy:buffer length:16];
}

#include "ActivatorIntegrationHelper.h"

%ctor
{
    %init;

    if (kCFCoreFoundationVersionNumber >= 1443.00) {
        %init(iOS11andAbove);
    } else if (kCFCoreFoundationVersionNumber >= 1348.00) {
        %init(iOS10);
    } else {
        %init(iOS9);
    }

    setDarwinNCObserver(passBySettingsChanged,  CFSTR("com.giorgioiavicoli.passby/reload"));
    setDarwinNCObserver(passByWiFiListChanged,  CFSTR("com.giorgioiavicoli.passby/wifi"));
    setDarwinNCObserver(passByBTListChanged,    CFSTR("com.giorgioiavicoli.passby/bt"));
    setDarwinNCObserver(flipSwitchOn,           CFSTR("com.giorgioiavicoli.passbyflipswitch/on"));
    setDarwinNCObserver(flipSwitchOff,          CFSTR("com.giorgioiavicoli.passbyflipswitch/off"));

	dlopen("/System/Library/PrivateFrameworks/SpringBoardUIServices.framework/SpringBoardUIServices", RTLD_LAZY);
	dlopen("/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework/UserNotificationsUIKit", RTLD_LAZY);

    setDarwinNCObserver(displayStatusChanged,   CFSTR("com.apple.iokit.hid.displayStatus"));
    setDarwinNCObserver(lockstateChanged,       CFSTR("com.apple.springboard.lockstate"));

    getUUID();

    passBySettingsChanged(NULL, NULL, NULL, NULL, NULL);
    passByWiFiListChanged(NULL, NULL, NULL, NULL, NULL);
    passByBTListChanged(NULL, NULL, NULL, NULL, NULL);

    unlockedWithTimeout = NO;
    wasUsingHeadphones  = NO;
    isInSOSMode         = NO;
    isKeptDisabled      = NO;
    isManuallyDisabled  = NO;
    isDisabledUntilNext = NO;
    lastLockedState     = YES;

    WiFiGracePeriodSyncObj  = [NSObject new];
    BTGracePeriodSyncObj    = [NSObject new];
    ManuallyDisabledSyncObj = [NSObject new];

    if (savePasscode) {
        loadAllGracePeriods();
    }

    void* wifiLibHandle = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    if (wifiLibHandle) {
        WiFiRegisterLinkCallback_t WiFiRegisterLinkCallback_sym;
        *(void **) (&WiFiRegisterLinkCallback_sym) = dlsym(wifiLibHandle, "WiFiDeviceClientRegisterLinkCallback");
        if(WiFiRegisterLinkCallback_sym) {
            WiFiDeviceClientRef _device = 
                MSHookIvar<WiFiDeviceClientRef>(
                    [SBWiFiManager sharedInstance], "_device"
                );
            if (_device) {
                (*WiFiRegisterLinkCallback_sym)(_device, _WiFiLinkDidChange, NULL);
            }
        }
    }

    if (dlopen("/usr/lib/libactivator.dylib", RTLD_NOW)) {
        Class LAActivatorClass = objc_getClass("LAActivator");
        if (LAActivatorClass) {
            static PassByListener * passbyActivatorListener = [PassByListener new];
            [   [LAActivatorClass sharedInstance]
                registerListener:passbyActivatorListener
                forName:@PASSBY_UNLOCK_LALISTENER_NAME
            ];
            [   [LAActivatorClass sharedInstance]
                registerListener:passbyActivatorListener
                forName:@PASSBY_INVALIDATE_LALISTENER_NAME
            ];
        }
    }
}