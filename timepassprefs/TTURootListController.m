#import <notify.h>
#include "TPRootListController.h"

#define PLIST_PATH      "/var/mobile/Library/Preferences/com.giorgioiavicoli.timepass.plist"
#define WIFI_PLIST_PATH "/var/mobile/Library/Preferences/com.giorgioiavicoli.timepassnets.plist"


@implementation TPRootListController

- (NSArray *)specifiers 
{
	if (!_specifiers)
		_specifiers =   [   [self   loadSpecifiersFromPlistName:@"Root" 
                                    target:self
                            ] retain
                        ];
	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier 
{
    return  (   [   [[NSDictionary alloc]
                    initWithContentsOfFile:@PLIST_PATH
                    ] retain
                ] [[specifier propertyForKey:@"key"]]
            ) ?:[specifier properties][@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier 
{
    NSMutableDictionary * settings =    
        [   [NSMutableDictionary alloc] 
            initWithContentsOfFile:@PLIST_PATH
        ] ?:[NSMutableDictionary new];
    [settings 
        setObject:value 
        forKey:[specifier propertyForKey:@"key"]
    ];
    [settings writeToFile:@(PLIST_PATH) atomically:YES];
    [settings release];
	notify_post("com.giorgioiavicoli.timepass/SettingsChanged");
}

-(BOOL)validateTimeShift:(id)value
{
    NSScanner * scanner = [[NSScanner alloc] initWithString:value];
    int i = 0;
    BOOL isNum = [scanner scanInt:&i] && [scanner isAtEnd];
    [scanner release];

    if (isNum || ![value length])
        return TRUE;
    
    UIAlertView *alert = [  [UIAlertView alloc]
                            initWithTitle:@"Error"
                            message: @"Time shift value must be an integer number (minutes)"
                            delegate:self
                            cancelButtonTitle:@"OK"
                            otherButtonTitles:nil
                        ];
    [alert show];
    [alert release];
    return FALSE;
}

-(BOOL)validateDigits:(id)value forKey:(NSString *)key
{
    if([value length] != 2) {
        UIAlertView *alert = [  [UIAlertView alloc]
                                initWithTitle:@"Error"
                                message: @"Field must contain exacly TWO digits"
                                delegate:self
                                cancelButtonTitle:@"OK"
                                otherButtonTitles:nil
                        ];
        [alert show];
        [alert release];
        return FALSE;
    } else if ([value characterAtIndex:0] < '0' || [value characterAtIndex:0] > '9' 
            || [value characterAtIndex:1] < '0' || [value characterAtIndex:1] > '9' ) {
        UIAlertView *alert = [  [UIAlertView alloc]
                                initWithTitle:@"Error"
                                message: @"Field must contain digits ONLY"
                                delegate:self
                                cancelButtonTitle:@"OK"
                                otherButtonTitles:nil
                        ];
        [alert show];
        [alert release];
        return FALSE;
    }
    return TRUE;
}

-(void)resetSettings:(id)arg1 
{
    [@{} writeToFile:@PLIST_PATH        atomically:YES];
    [@{} writeToFile:@WIFI_PLIST_PATH   atomically:YES];
    [self reloadSpecifiers];
}

-(void)passcodeChanged:(id)arg1 
{
    notify_post("com.giorgioiavicoli.timepass/CodeChanged");
}

-(void)sourceCode:(id)arg1 
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.apple.com"]];
}

@end

@implementation TPWiFiListController

- (NSArray *)specifiers 
{
	if (!_specifiers) {
        NSMutableArray * specifiers = [NSMutableArray new];
        NSDictionary * networksList =   [   [NSDictionary alloc] 
                                            initWithContentsOfFile:@WIFI_PLIST_PATH
                                        ] ?: [NSDictionary new];

        WiFiManagerRef manager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
        if(manager) {
            NSArray * networks = (NSArray *) WiFiManagerClientCopyNetworks(manager);
            if(networks) {
                for(id network in networks) {
                    NSString * name = (NSString *) WiFiNetworkGetSSID((WiFiNetworkRef)network);
                    if(name) {
                        PSSpecifier * specifier = [ PSSpecifier 
                                                        preferenceSpecifierNamed:name
                                                        target:self
                                                        set:@selector(setPreferenceValue:specifier:)
                                                        get:@selector(readPreferenceValue:)
                                                        detail:Nil
                                                        cell:PSSwitchCell
                                                        edit:Nil
                                                    ];
                        [specifier setProperty:[NSString stringWithString:name] forKey:@"key"];
                        [specifier setProperty:[[NSNumber alloc] initWithBool:TRUE] forKey:@"enabled"];
                        [specifier 
                            setProperty:[[networksList valueForKey:SHA1(name)] copy]?:@(0)
                            forKey:@"default"
                        ];
                        [specifiers addObject:specifier];
                    }
                }
            }
        }
        [networksList release];
        _specifiers = [specifiers retain];
    }

    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier 
{
    NSString * key = [specifier propertyForKey:@"key"];
    return [[NSDictionary alloc] initWithContentsOfFile:@WIFI_PLIST_PATH][key] ?:[specifier properties][@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier 
{
    NSMutableDictionary * settings =    [  [NSMutableDictionary alloc] 
                                            initWithContentsOfFile:@WIFI_PLIST_PATH
                                        ] ?:[NSMutableDictionary new];
    [settings 
        setObject:value 
        forKey:[SHA1([specifier propertyForKey:@"key"]) autorelease]
    ];
    [settings writeToFile:@(WIFI_PLIST_PATH) atomically:YES];
    [settings release];
    notify_post("com.giorgioiavicoli.timepass/WiFiListChanged");
}
@end


#import <CommonCrypto/CommonDigest.h>
NSString * SHA1(NSString * str)
{
    NSMutableData * hashData = [[NSMutableData alloc] initWithLength:CC_SHA1_DIGEST_LENGTH];
    NSData * data = [str dataUsingEncoding:NSUTF8StringEncoding];

    unsigned char * hashBytes = (unsigned char *)[hashData mutableBytes];

    if (CC_SHA1([data bytes], [data length], hashBytes)) {
        NSUInteger len  = [hashData length];
        NSMutableString * hash  = [NSMutableString stringWithCapacity:(len * 2)];
        
        for (int i = 0; i < len; ++i)
            [hash appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)hashBytes[i]]];
        
        return [[NSString alloc] initWithString:hash];
    }
    return nil;
}