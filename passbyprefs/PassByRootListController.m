#import <MessageUI/MessageUI.h>
#include <notify.h>
#include <objc/runtime.h>

#include "PassByRootListController.h"
#include "../crypto.h"

#define PLIST_PATH      "/var/mobile/Library/Preferences/com.giorgioiavicoli.passby.plist"
#define WIFI_PLIST_PATH "/var/mobile/Library/Preferences/com.giorgioiavicoli.passbynets.plist"
#define BT_PLIST_PATH "/var/mobile/Library/Preferences/com.giorgioiavicoli.passbybt.plist"


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
            } else if (len <= 4 && [value characterAtIndex:len-3] != ':') {
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


-(void)donate:(id)arg1 
{
    if ([UIApplication respondsToSelector:@selector(openURL:options:completionHandler:)]) {
        [   [UIApplication sharedApplication] 
            openURL:[NSURL URLWithString:@"https://paypal.me/giorgioiavicoli"] 
            options:@{} 
            completionHandler:nil
        ];
    } else {
        [   [UIApplication sharedApplication] 
            openURL:[NSURL URLWithString:@"https://paypal.me/giorgioiavicoli"] 
        ];
    }
}

-(void)resetSettings:(id)arg1 
{
    [@{} writeToFile:@PLIST_PATH        atomically:YES];
    [@{} writeToFile:@WIFI_PLIST_PATH   atomically:YES];
    [@{} writeToFile:@BT_PLIST_PATH     atomically:YES];
	notify_post("com.giorgioiavicoli.passby/reload");
    [self reloadSpecifiers];
}

-(void)sendFeedback:(id)arg1 
{
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController * mailComposeVC = [[MFMailComposeViewController alloc] init];
        mailComposeVC.mailComposeDelegate = self;
        
        [mailComposeVC setToRecipients:@[@"giorgio.iavicoli@icloud.com"]];
        [mailComposeVC setSubject:@"Feedback on PassBy"];

        UIAlertController * alertController = 
            [UIAlertController alertControllerWithTitle:@"Attach settings"
                message:@"Do you want to include your settings in the feedback? \n This will NOT include names of WiFi nor Bluetooth devices"
                preferredStyle:UIAlertControllerStyleAlert
            ];
        
        UIAlertAction * yesAction = 
            [UIAlertAction 
                actionWithTitle:@"Yes" 
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction * action) 
                {
                    [mailComposeVC 
                        addAttachmentData:[NSData dataWithContentsOfFile:@PLIST_PATH] 
                        mimeType:@"application/xml" 
                        fileName:@"PassBySettings.plist"
                    ];
                    [self
                        presentViewController:mailComposeVC 
                        animated:YES 
                        completion:nil
                    ];
                }
            ];
        
        UIAlertAction * noAction = 
            [UIAlertAction 
                actionWithTitle:@"No" 
                style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) 
                {
                    [self
                        presentViewController:mailComposeVC 
                        animated:YES 
                        completion:nil
                    ];
                }
            ];

        [alertController addAction:yesAction];
        [alertController addAction:noAction];
        [self 
            presentViewController:alertController 
            animated:YES 
            completion:nil
        ];
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

NSMutableArray * protectedNetworks;

- (NSArray *)specifiers 
{
	if (!_specifiers) {
        NSMutableArray * specifiers = [NSMutableArray new];
        protectedNetworks = [NSMutableArray new];
        NSDictionary * networksList =   
            [   [NSDictionary alloc] 
                initWithContentsOfFile:@WIFI_PLIST_PATH
            ] ?: [NSDictionary new];

        WiFiManagerRef manager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
        if (manager) {
            NSArray * networks = (__bridge NSArray *) WiFiManagerClientCopyNetworks(manager);
            if (networks) {
                for(id network in networks) {
                    NSString * name = (NSString *) WiFiNetworkGetSSID((WiFiNetworkRef)network);

                    if (name) {
                        PSSpecifier * specifier =
                            [ PSSpecifier 
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

                        if (WiFiNetworkIsWEP((WiFiNetworkRef)network)
                        ||  WiFiNetworkIsWPA((WiFiNetworkRef)network)
                        ||  WiFiNetworkIsEAP((WiFiNetworkRef)network)
                        ) {
                            [protectedNetworks 
                                addObject:
                                    [NSString stringWithString:name]];
                        }
                    }
                }
                [networks release];
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

- (void)realSetPreferenceValue:(NSString*)name value:(id)value
{
    NSMutableDictionary * settings =    
        [  [NSMutableDictionary alloc] 
            initWithContentsOfFile:@WIFI_PLIST_PATH
        ] ?:[NSMutableDictionary new];
    [settings 
        setObject:value 
        forKey:SHA1(name)
    ];
    [settings writeToFile:@(WIFI_PLIST_PATH) atomically:YES];
    [settings release];
    notify_post("com.giorgioiavicoli.passby/wifi");
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier 
{
    NSString * name = [specifier propertyForKey:@"key"];

    if ([value boolValue] 
    && ![protectedNetworks containsObject: name]
    ) {
        UIAlertController * alert =    
            [UIAlertController
                alertControllerWithTitle:@"Unprotected network"
                message:@"Adding this open network to the whitelist will make your device vulnerable. DO NOT enable THIS network if you are using the option \"Even when connected while locked\""
                preferredStyle: UIAlertControllerStyleActionSheet
            ];

        [alert addAction: 
            [UIAlertAction 
                actionWithTitle:@"Proceed anyway" 
                style:UIAlertActionStyleDestructive
                handler: 
                    ^(UIAlertAction * action) 
                    { [self realSetPreferenceValue:name value:value]; }
            ]
        ];


        [alert addAction: 
            [UIAlertAction 
                actionWithTitle:@"Cancel" 
                style:UIAlertActionStyleCancel
                handler:
                    ^(UIAlertAction * action) 
                    { [self reloadSpecifiers]; }
            ]
        ];

        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [self realSetPreferenceValue:name value:value];
    }
}

@end


@implementation PassByBTListController

- (NSArray *)specifiers 
{
	if (!_specifiers) {
        NSMutableArray * specifiers = [NSMutableArray new];

        NSDictionary * bluetoothList =  
            [   [NSDictionary alloc] 
                initWithContentsOfFile:@BT_PLIST_PATH
            ] ?: [NSDictionary new];

        BluetoothManager *  bluetoothManager    = [BluetoothManager sharedInstance];
        NSArray          *  pairedDevices       = [bluetoothManager pairedDevices];

        if ([pairedDevices count]) {
            for (BluetoothDevice * bluetoothDevice in pairedDevices) {
                NSString * name = [bluetoothDevice name];

                if (name) {
                    PSSpecifier * specifier = 
                        [ PSSpecifier 
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
                        setProperty:[[bluetoothList valueForKey:SHA1(name)] copy]?:@(NO)
                        forKey:@"default"
                    ];
                    [specifiers addObject:specifier];
                }
            }
        }
        
        [bluetoothList release];
        _specifiers = [specifiers retain];
    }

    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier 
{
    NSString * key = [specifier propertyForKey:@"key"];
    return [[NSDictionary alloc] initWithContentsOfFile:@BT_PLIST_PATH][key] 
        ?:[specifier properties][@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier 
{
    NSMutableDictionary * settings =    
        [  [NSMutableDictionary alloc] 
            initWithContentsOfFile:@BT_PLIST_PATH
        ] ?:[NSMutableDictionary new];
    [settings 
        setObject:value 
        forKey:SHA1([specifier propertyForKey:@"key"])
    ];
    [settings writeToFile:@BT_PLIST_PATH atomically:YES];
    [settings release];
    notify_post("com.giorgioiavicoli.passby/bt");
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