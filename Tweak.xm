#import <notify.h>

#import "NSData+AES.h"

static BOOL isTweakEnabled;
static BOOL isReversed;
static BOOL shouldAlwaysShowTime;
static BOOL use24hFormat;
static BOOL isSixDigitPasscode;
static BOOL isParanoid;

static int      timeShift;
static uint32_t kdRounds;

static NSData   *   UUID;
static NSData   *   saltData;
static NSData   *   passKey;
static NSString *   lastTwoDigits;
static NSString *   truePasscode;

#define PLIST_PATH      "/var/mobile/Library/Preferences/com.giorgioiavicoli.timepass.plist"
#define KEY_LENGTH      16
#define SALT_LENGTH     32 
#define HASH_TIME_MS    50 
//#define NSLog(...)

static void setValueForKey(id value, NSString *key) 
{
    NSLog(@"*g* Setting value for key %@", key);
    NSMutableDictionary * timePassDict = [[NSMutableDictionary alloc] initWithContentsOfFile:@PLIST_PATH]?:[NSMutableDictionary dictionary];
    timePassDict[key] = value;
    [timePassDict writeToFile:@(PLIST_PATH) atomically:YES];
    [timePassDict release];
}

static void timePassSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) 
{
    NSMutableDictionary *timePassDict = [   [   [NSDictionary alloc] 
                                                initWithContentsOfFile:@PLIST_PATH
                                            ]?: [NSDictionary dictionary] copy
                                        ];

    isTweakEnabled              =       [[timePassDict valueForKey:@"isEnabled"]            ?:@NO boolValue];
    isReversed                  =       [[timePassDict valueForKey:@"isReversed"]           ?:@NO boolValue];
    shouldAlwaysShowTime        =       [[timePassDict valueForKey:@"shouldAlwaysShowTime"] ?:@YES boolValue];
    use24hFormat                =       [[timePassDict valueForKey:@"use24hFormat"]         ?:@YES boolValue];
    isSixDigitPasscode          =       [[timePassDict valueForKey:@"isSixDigitPasscode"]   ?:@YES boolValue];
    isParanoid                  =       [[timePassDict valueForKey:@"isParanoid"]           ?:@NO boolValue];
    timeShift                   = (int) [[timePassDict valueForKey:@"timeShift"]            ?:@(0) intValue];
    lastTwoDigits               =       [[timePassDict valueForKey:@"lastTwoDigits"]        ?:@"00" copy];


    kdRounds = (uint32_t)   (timePassDict[@"kdRounds"]  = [timePassDict valueForKey:@"kdRounds"]            
                                                            ?:@(calibrateRounds(KEY_LENGTH, 
                                                                                SALT_LENGTH, 
                                                                                HASH_TIME_MS
                                                                                )
                                                                )
                            );
    
    saltData = [timePassDict  valueForKey:@"saltData"];
    if (!saltData || [saltData length] != SALT_LENGTH)
        timePassDict[@"saltData"] = saltData = generateSalt(SALT_LENGTH);

    NSData * truePasscodeData   =       [timePassDict  valueForKey:@"truePasscodeData"];
    if (truePasscodeData && [truePasscodeData length])
        truePasscode = [[NSString alloc] 
                        initWithData:AES128Decrypt( truePasscodeData, 
                                                    passKey = deriveAES128Key(UUID, saltData, kdRounds))
                        encoding:NSUTF8StringEncoding
                        ];
    [truePasscodeData release];

    [timePassDict writeToFile:@(PLIST_PATH) atomically:YES];
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

    unsigned char * buffer = (unsigned char *) alloca(16);
    [[[UIDevice currentDevice] identifierForVendor] getUUIDBytes:buffer];
    UUID = [NSData dataWithBytes:buffer length:16];
    free(buffer);
}


NSString * reverseStr(NSString *string) 
{
    NSInteger len = [string length];
    NSMutableString *reversed = [NSMutableString stringWithCapacity:len];
    
    for (NSInteger i = (len - 1); i >= 0; i--)
        [reversed appendFormat:@"%c", [string characterAtIndex:i]];

    return [reversed autorelease];
}

NSString * magicPasscode() 
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[NSLocale currentLocale]];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:(use24hFormat) ? @"HHmm" : @"hhmm"];
    
    NSMutableString * pass = timeShift 
                                ? [[formatter stringFromDate:[[NSDate date] dateByAddingTimeInterval:timeShift * 60]] mutableCopy] 
                                : [[formatter stringFromDate:[NSDate date]] mutableCopy];
    [pass autorelease];
    [formatter release];

    if (isSixDigitPasscode)
        [pass appendString: (lastTwoDigits && lastTwoDigits.length == 2) ? lastTwoDigits : @"00"];

    return isReversed ? reverseStr(pass) : pass;
}


@interface SBLockScreenManager : NSObject
@property(readonly) BOOL isUILocked;
//+ (id)sharedInstance;
//- (BOOL)attemptUnlockWithPasscode:(id)arg1;
- (void)attemptUnlockWithPasscode:(id)arg1 completion:(/*^block*/id)arg2 ;
@end

%hook SBLockScreenManager
- (void)attemptUnlockWithPasscode:(NSString*)passcode completion:(id)arg2 {
    if (!isTweakEnabled)
        return %orig;
    
    if (truePasscode && [truePasscode length]) {
        if ([passcode isEqualToString:magicPasscode()]) 
            %orig(truePasscode, arg2);
        else 
            %orig;
    } else {
        %orig;
        if (![self isUILocked]) {
            UIAlertView *alert =    [   [UIAlertView alloc]
                                        initWithTitle:@"TimePass"
                                        message:@"TimePass enabled!"
                                        delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil
                                    ];
            [alert show];
            [alert release];

            truePasscode = [passcode copy];

            if (!isParanoid)
                setValueForKey( AES128Encrypt([passcode dataUsingEncoding:NSUTF8StringEncoding], passKey), 
                                @"truePasscodeData");
        }
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
