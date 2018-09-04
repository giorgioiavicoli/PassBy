#import <Foundation/Foundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CommonCrypto/CommonDigest.h>
#import <notify.h>

static BOOL isTweakEnabled;
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
static uint64_t     lastLockstate       = 3;

#define PLIST_PATH                  "/var/mobile/Library/Preferences/com.giorgioiavicoli.passby.plist"
#define WIFI_PLIST_PATH             "/var/mobile/Library/Preferences/com.giorgioiavicoli.passbynets.plist"
#define LOCKSTATE_NEEDSAUTH_MASK    0x02

BOOL        passcodeChecksOut(NSString * passcode);
BOOL        isUsingHeadphones();
BOOL        isUsingWiFi();


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
            ? [[[NSDate new] dateByAddingTimeInterval: gracePeriodOnWiFi] retain]
            : nil;

    gracePeriodEnds = 
        useGracePeriod 
            ? [[[NSDate new] dateByAddingTimeInterval: gracePeriod] retain]
            : nil;
    
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
    } else if (truePasscode && [truePasscode length]) {
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
    } else if (truePasscode && [truePasscode length]) {
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

BOOL passcodeChecksOut(NSString * passcode) 
{
    return first.eval(&first, [passcode characterAtIndex:0], [passcode characterAtIndex:1])
        && second.eval(&second, [passcode characterAtIndex:2], [passcode characterAtIndex:3])
        && (!isSixDigitPasscode || last.eval(&last, [passcode characterAtIndex:4], [passcode characterAtIndex:5]));
}

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

void parseDigitsConfiguration(struct Digits * digits, NSString * str)
{
    if(!str || [str length] != 2) {
        digits->eval = evalCustom;
    } else {
        char c0 = [str characterAtIndex:0];
        char c1 = [str characterAtIndex:1];

        if(c0 == 't') {
            if(c1 == 'h')
                digits->eval = evalTimeH;
            else if(c1 == 'm')
                digits->eval = evalTimeM;
        } else if(c0 == 'd') {
            if(c1 == 'd')
                digits->eval = evalDateD;
            else if(c1 == 'm')
                digits->eval = evalDateM;
        } else if(c0 == 'b') {
            if(c1 == 'r')
                digits->eval = evalBattR;
            else if(c1 == 'u')
                digits->eval = evalBattU;
        } else if(c0 == 'c' && c1 == 'd') {
            digits->eval = evalCustom;
        } else if(c0 == 'g' && c1 == 'p') {
            digits->eval = evalGraceP;
            digits->isGracePeriod = true;
        } else {
            digits->eval = evalCustom;
        }
    }
}


static void passBySettingsChanged(CFNotificationCenterRef center, void * observer, 
                                    CFStringRef name, void const * object, CFDictionaryRef userInfo) 
{
    NSDictionary * passByDict =   [   [NSDictionary alloc] 
                                        initWithContentsOfFile:@PLIST_PATH
                                    ]?: [NSDictionary new];

    isTweakEnabled          =   [[passByDict valueForKey:@"isEnabled"]              ?:@NO boolValue];
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

    NSString * digits;
    digits                  =   [passByDict valueForKey:@"firstTwoCustomDigits"]    ?:@"00";
    if ([digits length] == 2) {
        first.digit0            =   [digits characterAtIndex:0];
        first.digit1            =   [digits characterAtIndex:1];
    } else {
        first.digit1 = first.digit0 = '0';
    }
    parseDigitsConfiguration(&first, [passByDict valueForKey:@"firstTwo"] ?:@"cd");
    first.reversed          =   [[passByDict valueForKey:@"firstTwoReversed"]       ?:@NO boolValue];

    digits                  =   [passByDict valueForKey:@"secondTwoCustomDigits"]   ?:@"00";
    if ([digits length] == 2) {
        second.digit0           =   [digits characterAtIndex:0];
        second.digit1           =   [digits characterAtIndex:1];
    } else {
        second.digit1 = second.digit0 = '0';
    }
    parseDigitsConfiguration(&second, [passByDict valueForKey:@"secondTwo"] ?:@"cd");
    second.reversed         =   [[passByDict valueForKey:@"secondTwoReversed"]      ?:@NO boolValue];

    digits                  =   [passByDict valueForKey:@"lastTwoCustomDigits"]     ?:@"00";
    if ([digits length] == 2) {
        last.digit0             =   [digits characterAtIndex:0];
        last.digit1             =   [digits characterAtIndex:1];
    } else {
        last.digit1 = last.digit0 = '0';
    }
    parseDigitsConfiguration(&last, [passByDict valueForKey:@"lastTwo"] ?:@"cd");
    last.reversed           =   [[passByDict valueForKey:@"lastTwoReversed"]        ?:@NO boolValue];


    if ([[passByDict valueForKey:@"gracePeriodUnit"] ?:@"m" characterAtIndex:0] == 'm')
        gracePeriod *= 60;
    
    if ([[passByDict valueForKey:@"gracePeriodUnitOnWiFi"] ?:@"m" characterAtIndex:0] == 'm')
        gracePeriodOnWiFi *= 60;

    if ([[passByDict valueForKey:@"timeShiftDirection"] ?:@"+" characterAtIndex:0] == '-')
        timeShift = -timeShift;

    [passByDict release];    
}

static void passByWiFiListChanged(CFNotificationCenterRef center, void * observer, 
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

static void displayStatusChanged(   CFNotificationCenterRef center, void * observer, 
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

static void lockstateChanged(   CFNotificationCenterRef center, void * observer, 
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

%ctor 
{
    %init;
    if(kCFCoreFoundationVersionNumber >= 1443.00)
        %init(iOS11)
    else
        %init(iOS10)

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

    passBySettingsChanged(NULL, NULL, NULL, NULL, NULL);
    passByWiFiListChanged(NULL, NULL, NULL, NULL, NULL);
    unlockedWithTimeout = NO;
    wasUsingHeadphones  = NO;
    isInSOSMode         = NO;
}