#import <notify.h>

#include "TPRootListController.h"


#define PLIST_PATH "/var/mobile/Library/Preferences/com.giorgioiavicoli.timepass.plist"

@implementation TPRootListController

- (NSArray *)specifiers {
	if (!_specifiers)
		_specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] retain];

	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
      @autoreleasepool {
      	return ([[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH][[specifier properties][@"key"]]) ?: [specifier properties][@"default"];
      }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    if ([[specifier properties][@"key"] isEqualToString:@"timeShift"]) {
        NSScanner * scanner = [NSScanner scannerWithString:value];
        int i;
        BOOL isNum = [scanner scanInt:&i] && [scanner isAtEnd];

        if (!isNum && [value length]) {
            UIAlertView *alert = [  [UIAlertView alloc]
                                    initWithTitle:@"Error"
                                    message: @"Time shift value must be positive or negative integer"
                                    delegate:self
                                    cancelButtonTitle:@"OK"
                                    otherButtonTitles:nil
                                  ];
            [alert show];
            [alert release];
            return;
        }
    }

    if ([[specifier properties][@"key"] isEqualToString:@"lastTwoDigits"]) {
        NSScanner * scanner = [NSScanner scannerWithString:value];
        int i;
        BOOL isNum = [scanner scanInt:&i] && [scanner isAtEnd];
        
        if ((!isNum || i < 0) && [value length]) {
            UIAlertView *alert = [  [UIAlertView alloc]
                                    initWithTitle:@"Error"
                                    message: @"Two last digits must be positive numbers"
                                    delegate:self
                                    cancelButtonTitle:@"OK"
                                    otherButtonTitles:nil
                                  ];
            [alert show];
            [alert release];
            return;
        }
        if ([value length] != 2 && [value length]) {
            UIAlertView *alert = [  [UIAlertView alloc]
                                    initWithTitle:@"Error"
                                    message: @"Only enter 2 digits please"
                                    delegate:self
                                    cancelButtonTitle:@"OK"
                                    otherButtonTitles:nil];
            [alert show];
            [alert release];
            return;
        }
    }

    NSMutableDictionary * settings = [[[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH]?:[NSDictionary dictionary] mutableCopy];
	[settings setObject:value forKey: [specifier properties][@"key"]];
	[settings writeToFile:@(PLIST_PATH) atomically:YES];
    [settings release];
	notify_post("com.giorgioiavicoli.timepass/SettingsChanged");
}

-(void)resetSettings:(id)arg1 {
    [@{} writeToFile:@PLIST_PATH atomically:YES];
    [self reloadSpecifiers];
}

-(void)passcodeChanged:(id)arg1 {
    NSMutableDictionary * settings = [[[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH]?:[NSDictionary dictionary] mutableCopy];
	[settings setObject:[NSMutableData dataWithLength:0] forKey:@"realPasscodeData"];
	[settings writeToFile:@(PLIST_PATH) atomically:YES];
    [settings release];
}

@end
