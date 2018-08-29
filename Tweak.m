#import <notify.h>

#import "NSData+AES.h"

static BOOL isTweakEnabled;
static BOOL isReversed;
static BOOL shouldAlwaysShowTime;
static BOOL isSixDigitPasscode;

static int  timeShift;

static NSMuableData *   UUID;
static NSString     *   lastTwoDigits;
static NSData       *   realPasscodeData;

#define PLIST_PATH "/var/mobile/Library/Preferences/com.giorgioiavicoli.timepass.plist"
//#define NSLog(...)

static void setValueForKey(id value, NSString *key) 
{
    NSLog(@"*g* Setting value for key %@", key);
    NSMutableDictionary * timePassDict = [[NSMutableDictionary alloc] initWithContentsOfFile:@PLIST_PATH]?:[NSMutableDictionary dictionary];
    timePassDict[key] = value;
    [timePassDict writeToFile:@(PLIST_PATH) atomically:YES];
    [timePassDict release];
    notify_post("com.giorgioiavicoli.timepass/SettingsChanged");
}

static void timePassSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) 
{
    NSDictionary *timePassDict =    [   [   [NSDictionary alloc] 
                                            initWithContentsOfFile:@PLIST_PATH
                                        ]?: [NSDictionary dictionary] copy
                                    ];

    isTweakEnabled          =       [[timePassDict valueForKey:@"isEnabled"]            ?:@NO boolValue];
    isReversed              =       [[timePassDict valueForKey:@"isReversed"]           ?:@NO boolValue];
    shouldAlwaysShowTime    =       [[timePassDict valueForKey:@"shouldAlwaysShowTime"] ?:@YES boolValue];
    use24hFormat            =       [[timePassDict valueForKey:@"use24hFormat"]         ?:@YES boolValue];
    isSixDigitPasscode      =       [[timePassDict valueForKey:@"isSixDigitPasscode"]   ?:@YES boolValue];

    realPasscodeData        =       [timePassDict  valueForKey:@"realPasscodeData"];
    timeShift               = (int) [[timePassDict valueForKey:@"timeShift"]            ?:@(0) intValue];
    lastTwoDigits           =       [[timePassDict valueForKey:@"lastTwoDigits"]        ?:@"00" copy];

    [timePassDict release];
}

%ctor 
{
	CFNotificationCenterAddObserver (   CFNotificationCenterGetDarwinNotifyCenter(), NULL, 
                                        timePassSettingsChanged,
                                        CFSTR("com.giorgioiavicoli.timepass/SettingsChanged"), NULL, 
                                        CFNotificationSuspensionBehaviorCoalesce
                                    );

	timePassSettingsChanged(NULL, NULL, CFSTR("com.giorgioiavicoli.timepass/SettingsChanged"), NULL, NULL);

    UUID = [NSMuableData initWithCapacity: 16]
    [[[UIDevice currentDevice] identifierForVendor] getUUIDBytes:UUID];
}


NSString * reverseStr(NSString *string) 
{
    int const len = string.length;
    NSMutableString *reversed = [NSMutableString stringWithCapacity:len];
    
    for (NSInteger i = (len - 1); i >= 0; i--)
        [reversed appendFormat:@"%c", [string characterAtIndex:i]];

    return reversed;
}

NSMutableString * passcodeFromTime() 
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[NSLocale currentLocale]];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:(use24hFormat) ? @"HHmm" : @"hhmm"];
    
    NSMutableString * pass = timeShift 
                                ? [[formatter stringFromDate:[[NSDate date] dateByAddingTimeInterval:timeShift * 60]] mutableCopy] 
                                : [[formatter stringFromDate:[NSDate date]] mutableCopy];

    if (isSixDigitPasscode)
        [pass appendString: (lastTwoDigits && lastTwoDigits.length == 2) ? lastTwoDigits : @"00"];

    NSLog(@"*g* the code would be %@", pass);

    return pass;
}


@interface SBLockScreenManager : NSObject
@property(readonly) BOOL isUILocked;
//+ (id)sharedInstance;
//- (BOOL)attemptUnlockWithPasscode:(id)arg1;
- (void)attemptUnlockWithPasscode:(id)arg1 completion:(/*^block*/id)arg2 ;
@end


%hook SBLockScreenManager

- (void)attemptUnlockWithPasscode:(NSString*)passcode completion:(id)arg2 {
    NSLog(@"*g* attempt with passcode %@", passcode);
    NSLog(@"*g* before orig %@", [self isUILocked] ? @"locked" : @"unlocked");
    %orig;
    NSLog(@"*g* after orig %@", [self isUILocked] ? @"locked" : @"unlocked");

    if (!isTweakEnabled || !passcode) 
        return;
    
    if (![self isUILocked]) {
        if (!realPasscodeData || ![realPasscodeData length]) {
            UIAlertView *alert =    [   [UIAlertView alloc]   
                                        initWithTitle:@"TimePass" 
                                        message:@"TimePass enabled!" 
                                        delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil
                                    ];
            [alert show];
            [alert release];
            
            realPasscodeData =  [   /*[*/passcode dataUsingEncoding:NSUTF8StringEncoding//] 
                                    //AES256EncryptWithKey:UUID
                                ];
            setValueForKey(realPasscodeData, @"realPasscodeData");
        }
    } else if (realPasscodeData && [realPasscodeData length] && [passcode isEqualToString:passcodeFromTime()]) {
        %orig(  [NSString stringWithUTF8String:[
                    [   [NSString alloc] 
                        initWithData:/*[*/realPasscodeData//AES256DecryptWithKey:UUID] 
                        encoding:NSUTF8StringEncoding
                    ] UTF8String]
                ], arg2
            );
    }
}
%end




@interface SBLockScreenViewControllerBase
- (BOOL)shouldShowLockStatusBarTime;
@end

%hook SBLockScreenViewControllerBase
- (BOOL)shouldShowLockStatusBarTime 
{
    return shouldAlwaysShowTime || %orig;
}
%end
