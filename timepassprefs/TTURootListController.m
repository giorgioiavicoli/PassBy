#import <notify.h>

#include "TPRootListController.h"


#define PLIST_PATH      "/var/mobile/Library/Preferences/com.giorgioiavicoli.timepass.plist"
#define WIFI_PLIST_PATH "/var/mobile/Library/Preferences/com.giorgioiavicoli.timepassnets.plist"


@implementation TPRootListController

- (NSArray *)specifiers 
{
	if (!_specifiers)
		_specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] retain];

	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier 
{
    NSString * key = [specifier propertyForKey:@"key"];
    NSLog(@"*g* Reading %@", key);
    return ([[[NSDictionary alloc] autorelease] initWithContentsOfFile:@PLIST_PATH][key]) ?: [specifier properties][@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier 
{
    NSString * key = [specifier propertyForKey:@"key"];

    NSLog(@"*g* Setting %@", key);

    if ([key isEqualToString:@"timeShift"] 
    && ![self validateTimeShift:value])
        return;

    /*
    if ([key isEqualToString:@"isSixDigitsPasscode"]) {
        NSArray * specifierToToggleVisibility = [NSArray arrayWithObjects: @"lastTwo",@"lastTwoReversed",@"lastTwoCustomDigits",nil];
        for(PSSpecifier * spec in _specifiers)
            if ([specifierToToggleVisibility containsObject:[spec properties][@"key"]])
                [specifier setProperty:value forKey:@"enabled"];
        [self reloadSpecifiers];
    }
    */

    if([[NSArray arrayWithObjects: @"firstTwoDigits",@"secondTwoDigits",@"lastTwoDigits",nil] containsObject:key]
    && ![self validateDigits:value forKey:key])
        return;

    NSLog(@"*g* Saving to file");
    NSMutableDictionary * settings = [[[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH] mutableCopy]?:[NSMutableDictionary dictionary];
    [settings setObject:value forKey: key];
    [settings writeToFile:@(PLIST_PATH) atomically:YES];
    [settings release];
    NSLog(@"*g* Saved to file");
	notify_post("com.giorgioiavicoli.timepass/SettingsChanged");
}

-(BOOL)validateTimeShift:(id)value
{
    NSScanner * scanner = [NSScanner scannerWithString:value];
    int i;
    BOOL isNum = [scanner scanInt:&i] && [scanner isAtEnd];
    [scanner release];

    if (isNum || ![value length])
        return TRUE;
    
    UIAlertView *alert = [  [UIAlertView alloc]
                            initWithTitle:@"Error"
                            message: @"Time shift value must be positive or negative integer"
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
    [@{} writeToFile:@PLIST_PATH atomically:YES];
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
/*
@implementation TPWiFiListController

- (NSArray *)specifiers 
{
	if (!_specifiers) {
        NSMutableArray * specifiers = [NSMutableArray alloc];
        NSDictionary * networksList = [[NSDictionary alloc] initWithContentsOfFile:@WIFI_PLIST_PATH];

        if(WiFiManagerRef manager = WiFiManagerClientCreate(kCFAllocatorDefault, 0))
            if(NSArray * networks = (NSArray *) WiFiManagerClientCopyNetworks(manager)) {
                [specifiers initWithCapacity:[networks count]];
                for(id network in networks)
                    if(NSString * name = (NSString *) WiFiNetworkGetSSID((WiFiNetworkRef)network)) {
                        PSSpecifier * specifier = [ PSSpecifier 
                                                        preferenceSpecifierNamed:name
                                                        target:self
                                                        set:@selector(setPreferenceValue:specifier:)
                                                        get:@selector(readPreferenceValue:)
                                                        detail:Nil
                                                        cell:PSSwitchCell
                                                        edit:Nil
                                                    ];
                        [specifier setProperty:@"Enabled" forKey:@"key"];
                        [specifier 
                            setProperty:[networksList valueForKey:name]?:@(0)
                            forKey:@"default"
                        ];
                        [specifiers addObject:specifier];
                    }
                        
            }
        _specifiers = [specifiers retain];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier 
{
    NSString * key = [specifier propertyForKey:@"key"];
    NSLog(@"*g* Reading wifi %@", key);
    return ([[[NSDictionary alloc] autorelease] initWithContentsOfFile:@PLIST_PATH][key]) ?: [specifier properties][@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier 
{
    NSString * key = [specifier propertyForKey:@"key"];

    NSLog(@"*g* Setting wifi %@", key);

    NSMutableDictionary * settings = [[[NSDictionary alloc] initWithContentsOfFile:@WIFI_PLIST_PATH] mutableCopy]?:[NSMutableDictionary dictionary];
    [settings setObject:value forKey: key];
    [settings writeToFile:@(WIFI_PLIST_PATH) atomically:YES];
    [settings release];
    NSLog(@"*g* Saved to file");
    notify_post("com.giorgioiavicoli.timepass/WiFiListChanged");
}
@end
*/