//
//  main.m
//  Test
//
//  Created by Giorgio Iavicoli on 29/08/2018.
//  Copyright © 2018 Giorgio Iavicoli. All rights reserved.
//

#import "NSData+AES.h"


NSString *str = @"test string!";
int const saltLen = 32;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSData * salt = generateSalt(saltLen);
        NSData * key = generateSalt(16);
        uint32_t rounds = calibrateRounds(16, saltLen, 50);
        NSData * derived = deriveAES128Key(key, salt, rounds);
        
        NSData * data = AES128Encrypt([str dataUsingEncoding:NSUTF8StringEncoding],
                                      derived);
        
        NSString * outstr = [   [NSString alloc]
                                initWithData:AES128Decrypt(data, derived)
                                encoding:NSUTF8StringEncoding
                            ];
        
        NSLog(@"Hello, World! %@ %@", outstr, [outstr isEqualToString:str] ? @"Yay!" : @"NOPE.");
    }
    return 0;
}
