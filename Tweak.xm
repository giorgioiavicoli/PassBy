#import <Foundation/Foundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <notify.h>

#include "crypto.h"

static BOOL isTweakEnabled;
static BOOL savePasscode;
static BOOL disableInSOSMode;
static BOOL use24hFormat;

static BOOL isSixDigitPasscode;
static BOOL useMagicPasscode;

static BOOL useGracePeriod;
static BOOL useGracePeriodOnWiFi;
static BOOL headphonesAutoUnlock;

static BOOL showLastUnlock;
static BOOL dismissLS;
static BOOL dismissLSWithMedia;

static BOOL NCHasContent;
static BOOL unlockedWithTimeout;
static BOOL wasUsingHeadphones;
static BOOL isInSOSMode;

static int  gracePeriod;
static int  gracePeriodOnWiFi;
static int  digitsGracePeriod;
static int  timeShift;

#include "PassByHelper.h"
struct Digits first, second, last;

static NSDate   *   lastUnlock          = nil;
static NSDate   *   gracePeriodWiFiEnds = nil;
static NSDate   *   gracePeriodEnds     = nil;
static NSTimer  *   graceTimeoutTimer   = nil;
static NSArray  *   allowedSSIDs        = nil;

static NSString *   truePasscode        = nil;
static NSData   *   UUID                = nil;
static uint64_t     lastLockstate       = 3;

#define PLIST_PATH                  "/var/mobile/Library/Preferences/com.giorgioiavicoli.passby.plist"
#define WIFI_PLIST_PATH             "/var/mobile/Library/Preferences/com.giorgioiavicoli.passbynets.plist"
#define LOCKSTATE_NEEDSAUTH_MASK    0x02

BOOL isUsingHeadphones();
BOOL isUsingWiFi();

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

static void updateLastUnlock()
{
    [lastUnlock release];
    lastUnlock = [NSDate new];
}

static void updateGracePeriods()
{
    [gracePeriodEnds release];
    [gracePeriodWiFiEnds release];

    gracePeriodWiFiEnds = 
        useGracePeriodOnWiFi && isUsingWiFi()
            ? (gracePeriodOnWiFi 
                ? [[[NSDate new] dateByAddingTimeInterval: gracePeriodOnWiFi] retain]
                : [[NSDate distantFuture] copy]
            ) : nil;

    gracePeriodEnds = 
        useGracePeriod 
            ? (gracePeriod
                ? [[[NSDate new] dateByAddingTimeInterval: gracePeriod] retain]
                : [[NSDate distantFuture] copy]
            ) : nil;
    
    wasUsingHeadphones = isUsingHeadphones();
}

static void unlockedWithPrimary(NSString * passcode)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            updateLastUnlock();
            isInSOSMode = NO;
            if (![passcode isEqualToString:truePasscode]) {
                [truePasscode release];
                truePasscode = [passcode copy];
                if (savePasscode)
                    savePasscodeToFile();
            }
        }
    );
}

static void unlockedWithPrimaryForFirstTime(NSString * passcode) 
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            updateLastUnlock();

            [truePasscode release];
            truePasscode = [passcode copy];
            if(savePasscode)
                savePasscodeToFile();

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
    );
}

BOOL passcodeChecksOut(NSString * passcode) 
{
    return first.eval(&first, [passcode characterAtIndex:0], [passcode characterAtIndex:1])
        && second.eval(&second, [passcode characterAtIndex:2], [passcode characterAtIndex:3])
        && (!isSixDigitPasscode 
            || last.eval(&last, [passcode characterAtIndex:4], [passcode characterAtIndex:5])
        );
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
            updateLastUnlock();

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

@class SBLockScreenViewControllerBase; //Forward declaration

@interface SBLockScreenManager : NSObject
@property(readonly) BOOL isUILocked;
+ (id)sharedInstance;
- (BOOL)attemptUnlockWithPasscode:(NSString *)passcode;
- (void)attemptUnlockWithPasscode:(NSString *)passcode completion:(/*^block*/id)arg2 ;
- (BOOL)_attemptUnlockWithPasscode:(NSString *)passcode finishUIUnlock:(BOOL)arg2;
- (SBLockScreenViewControllerBase *) lockScreenViewController;
@end


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
    NSString * passcode = [ [[NSString alloc] retain]
                            initWithData:[request payload]
                            encoding:NSASCIIStringEncoding
                        ];
    SBLockScreenManager * SBLSManager = [%c(SBLockScreenManager) sharedInstance];

    if (!isTweakEnabled 
    || !passcode 
    || [passcode length] != (isSixDigitPasscode ? 6 : 4)
    || (!useMagicPasscode && truePasscode)
    ) {
        %orig;
    } else if (truePasscode && [truePasscode length] == (isSixDigitPasscode ? 6 : 4)) {
        if (![truePasscode isEqualToString:passcode] && !isInSOSMode && passcodeChecksOut(passcode)) {
            [SBLSManager _attemptUnlockWithPasscode:truePasscode finishUIUnlock: YES];
            if (![SBLSManager isUILocked]) 
                unlockedWithSecondary();
        } else {
            %orig;
            if (![SBLSManager isUILocked]) 
                unlockedWithPrimary(passcode);
        }
    } else {
        %orig;
        if (![SBLSManager isUILocked]) 
            unlockedWithPrimaryForFirstTime(passcode);
    }
    [passcode release];
}
%end
%end

%group iOS11
%hook SBLockScreenManager
- (void)attemptUnlockWithPasscode:(NSString*)passcode completion:(id)arg2 
{
    if (!isTweakEnabled 
    || !passcode 
    || [passcode length] != (isSixDigitPasscode ? 6 : 4)
    || (!useMagicPasscode && truePasscode)
    ) {
        %orig;
        if (![self isUILocked])
            updateLastUnlock();
    } else if (truePasscode && [truePasscode length] == (isSixDigitPasscode ? 6 : 4)) {
        if (![truePasscode isEqualToString:passcode] && !isInSOSMode && passcodeChecksOut(passcode)) {
            %orig(truePasscode, arg2);
            if (![self isUILocked])
                unlockedWithSecondary();
        } else {
            %orig;
            if (![self isUILocked])
                unlockedWithPrimary(passcode);
        }
    } else {
        %orig;
        if (![self isUILocked]) 
            unlockedWithPrimaryForFirstTime(passcode);
    }
}
%end
%end


@interface SBUIPasscodeLockViewWithKeypad
- (id)statusTitleView;
@end

%hook SBUIPasscodeLockViewWithKeypad
- (id)statusTitleView
{
    if(isTweakEnabled) {
        if (!truePasscode) {
            UILabel * label = MSHookIvar<UILabel *>(self, "_statusTitleView");
            label.text = @"PassBy requires passcode";
            return label;
        } else if (showLastUnlock && lastUnlock) {
            NSMutableString * str = [NSMutableString stringWithString:@"Last unlock was at "];
            [str appendString:stringFromDateAndFormat(lastUnlock, use24hFormat ? @"HH:mm:ss" : @"hh:mm:ss a")];

            UILabel *label = MSHookIvar<UILabel *>(self, "_statusTitleView");
            label.text = str;
            return label;
        }
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
    NSString * SSID = ((NSDictionary *)CNCopyCurrentNetworkInfo(CFSTR("en0"))) [@"SSID"];
    return SSID && [SSID length] && useGracePeriodOnWiFi 
        && allowedSSIDs && [allowedSSIDs containsObject:SHA1(SSID)];
}

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

@interface SBLockScreenViewControllerBase
-(BOOL)isShowingMediaControls;
@end

@interface SBAssistantController
+(BOOL) isAssistantVisible;
@end

@interface SBLockStateAggregator : NSObject
+(id)sharedInstance;
-(unsigned long long)lockState;
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

BOOL isInGrace()
{
    if (gracePeriodEnds && [gracePeriodEnds compare:[NSDate date]] == NSOrderedDescending)
        return YES;

    if (gracePeriodWiFiEnds) {
        if (isUsingWiFi() && [gracePeriodWiFiEnds compare:[NSDate date]] == NSOrderedDescending) {
            return YES;
        } else {
            [gracePeriodWiFiEnds release];
            gracePeriodWiFiEnds = nil;
        }
    }

    if (headphonesAutoUnlock)
        return (wasUsingHeadphones = wasUsingHeadphones && isUsingHeadphones());

    return NO;
}


static void displayStatusChanged(   
    CFNotificationCenterRef center, void * observer, 
    CFStringRef name, void const * object, CFDictionaryRef userInfo) 
{
    if(isTweakEnabled && !isInSOSMode) {
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
    if(isTweakEnabled)
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                unsigned long long state = [[%c(SBLockStateAggregator) sharedInstance] lockState];

                if((state & LOCKSTATE_NEEDSAUTH_MASK) 
                && !(lastLockstate & LOCKSTATE_NEEDSAUTH_MASK)
                ) {
                    if (graceTimeoutTimer) {
                        [graceTimeoutTimer invalidate];
                        graceTimeoutTimer = nil;
                    } else if(unlockedWithTimeout) {
                        wasUsingHeadphones = NO;
                    } else {
                        updateGracePeriods();
                    }
                    unlockedWithTimeout = NO;
                }

                lastLockstate = state;
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
    disableInSOSMode        =   [[passByDict valueForKey:@"disableInSOSMode"]       ?:@YES boolValue];
    use24hFormat            =   [[passByDict valueForKey:@"use24hFormat"]           ?:@YES boolValue];
    showLastUnlock          =   [[passByDict valueForKey:@"showLastUnlock"]         ?:@NO boolValue];

    useGracePeriod          =   [[passByDict valueForKey:@"useGracePeriod"]         ?:@NO boolValue];
    gracePeriod             =   [[passByDict valueForKey:@"gracePeriod"]            ?:@(0) intValue];

    useGracePeriodOnWiFi    =   [[passByDict valueForKey:@"useGracePeriodOnWiFi"]   ?:@NO boolValue];
    gracePeriodOnWiFi       =   [[passByDict valueForKey:@"gracePeriodOnWiFi"]      ?:@(0) intValue];

    headphonesAutoUnlock    =   [[passByDict valueForKey:@"headphonesAutoUnlock"]   ?:@NO boolValue];

    dismissLS               =   [[passByDict valueForKey:@"dismissLS"]              ?:@NO boolValue];
    dismissLSWithMedia      =   [[passByDict valueForKey:@"dismissLSWithMedia"]     ?:@NO boolValue];

    timeShift               =   [[passByDict valueForKey:@"timeShift"]              ?:@(0) intValue];
    isSixDigitPasscode      =   [[passByDict valueForKey:@"isSixDigitPasscode"]     ?:@YES boolValue];
    useMagicPasscode        =   [[passByDict valueForKey:@"useMagicPasscode"]       ?:@NO boolValue];


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

    if ([[passByDict valueForKey:@"gracePeriodUnit"] ?:@"m" characterAtIndex:0] == 'm')
        gracePeriod *= 60;
    
    if ([[passByDict valueForKey:@"gracePeriodUnitOnWiFi"] ?:@"m" characterAtIndex:0] == 'm')
        gracePeriodOnWiFi *= 60;

    if ([[passByDict valueForKey:@"timeShiftDirection"] ?:@"+" characterAtIndex:0] == '-')
        timeShift = -timeShift;

    NSData * passcodeData = [passByDict valueForKey:@"passcode"];

    if (passcodeData) {
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
        if([[WiFiListDict valueForKey:key] boolValue])
            [WiFiListArr addObject:[key copy]];
    
    [WiFiListDict release];
    [allowedSSIDs release];
    allowedSSIDs = [[NSArray alloc] initWithArray:WiFiListArr copyItems:NO];
    [WiFiListArr release];
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
    if(kCFCoreFoundationVersionNumber >= 1443.00)
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
}