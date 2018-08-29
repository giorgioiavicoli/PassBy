//
//  NSData+AES.h
//  Test
//
//  Created by Giorgio Iavicoli on 29/08/2018.
//  Copyright © 2018 Giorgio Iavicoli. All rights reserved.
//

#ifndef NSData_AES_h
#define NSData_AES_h

#import <Foundation/Foundation.h>

NSData *    generateSalt
            (size_t length);

uint32_t    calibrateRounds
            (size_t keyLength,
             size_t saltLength,
             uint32_t calibratedDuration);

NSData *    deriveAES128Key
            (NSData *   key,
             NSData *   salt,
             uint32_t rounds);


NSData *    AES128Encrypt
            (NSData * data,
             NSData * key);

NSData *    AES128Decrypt
            (NSData * data,
             NSData * key);


#endif /* NSData_AES_h */
