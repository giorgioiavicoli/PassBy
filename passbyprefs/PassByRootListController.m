#import <notify.h>
#import <MessageUI/MessageUI.h>
#include "PassByRootListController.h"

#define PLIST_PATH      "/var/mobile/Library/Preferences/com.giorgioiavicoli.passby.plist"
#define WIFI_PLIST_PATH "/var/mobile/Library/Preferences/com.giorgioiavicoli.passbynets.plist"


@implementation PassByRootListController

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

    NSString * key = [specifier propertyForKey:@"key"];
        
    if ([key isEqualToString:@"savePasscode"]
    && [value boolValue] == NO
    ) {
        [settings removeObjectForKey:@"passcode"];
    } else if ([key isEqualToString:@"disableFromTime"] 
    || [key isEqualToString:@"disableToTime"]
    ) {
        int len = [value length];
        if (len) {
            if (len <= 2) {
                value = [value mutableCopy];
                [value appendString:@":00"];
            } else if (len <= 4) {
                value = [value mutableCopy];
                [value insertString:@":" atIndex:len-2];
            }
        }
    }

    [settings setObject:value forKey:key];
    [settings writeToFile:@(PLIST_PATH) atomically:YES];
    [settings release];
	notify_post("com.giorgioiavicoli.passby/reload");
    [self reloadSpecifiers];
}

-(void)resetSettings:(id)arg1 
{
    [@{} writeToFile:@PLIST_PATH        atomically:YES];
    [@{} writeToFile:@WIFI_PLIST_PATH   atomically:YES];
    [self reloadSpecifiers];
}

-(void)sendFeedback:(id)arg1 
{
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController * mailComposeVC = [[MFMailComposeViewController alloc] init];
        mailComposeVC.mailComposeDelegate = self;
        
        [mailComposeVC setToRecipients:@[@"giorgio.iavicoli@icloud.com"]];
        [mailComposeVC setSubject:@"Feedback on PassBy"];
    
        [self presentViewController:mailComposeVC animated:YES completion:nil];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
        didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error 
{
   [self dismissViewControllerAnimated:YES completion:nil];
}

@end


NSString * SHA1(NSString * str);

@implementation PassByWiFiListController

- (NSArray *)specifiers 
{
	if (!_specifiers) {
        NSMutableArray * specifiers = [NSMutableArray new];
        NSDictionary * networksList =   [   [NSDictionary alloc] 
                                            initWithContentsOfFile:@WIFI_PLIST_PATH
                                        ] ?: [NSDictionary new];

        WiFiManagerRef manager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
        if (manager) {
            NSArray * networks = (NSArray *) WiFiManagerClientCopyNetworks(manager);
            if (networks) {
                for(id network in networks) {
                    NSString * name = (NSString *) WiFiNetworkGetSSID((WiFiNetworkRef)network);
                    if (name) {
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
    notify_post("com.giorgioiavicoli.passby/wifi");
}
@end



@implementation PassByHelpListController
- (NSArray *)specifiers 
{
	if (!_specifiers)
		_specifiers =   
            [   [self
                    loadSpecifiersFromPlistName:@"Help" 
                    target:self
                ] retain
            ];
	return _specifiers;
}
@end

@implementation PassByMagicPasscodeListController
- (NSArray *)specifiers 
{
	if (!_specifiers)
		_specifiers = 
            [   
                [self   
                    loadSpecifiersFromPlistName:@"MagicPasscode" 
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
	notify_post("com.giorgioiavicoli.passby/reload");
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
