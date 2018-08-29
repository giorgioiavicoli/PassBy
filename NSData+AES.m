//
//  NSData+AES256.m
//  Test
//
//  Created by Giorgio Iavicoli on 29/08/2018.
//  Copyright © 2018 Giorgio Iavicoli. All rights reserved.
//

#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonCryptor.h>

#import "NSData+AES.h"

NSData * aes(NSData * data,
             NSData * key,
             CCOperation operation,
             CCOptions options);


@implementation NSData (AES)

NSData * AES128Encrypt(NSData * data, NSData * key)
{
    return aes(data, key,
               kCCEncrypt,
               kCCOptionPKCS7Padding);
}

NSData * AES128Decrypt(NSData * data, NSData * key)
{
    return aes(data, key,
               kCCDecrypt,
               kCCOptionPKCS7Padding);
}

@end

NSData * generateSalt(size_t length)
{
    NSMutableData * randomData = [NSMutableData dataWithLength:length];
    return SecRandomCopyBytes(  kSecRandomDefault,
                                length,
                                [randomData mutableBytes]
                             ) == errSecSuccess ? randomData : nil;
}

uint32_t calibrateRounds(size_t keyLength,
                         size_t saltLength,
                         uint32_t calibratedDuration)
{
    return CCCalibratePBKDF(    kCCPBKDF2,
                                keyLength,
                                saltLength,
                                kCCHmacAlgSHA512,
                                kCCKeySizeAES128,
                                calibratedDuration
                            );
}

NSData * deriveAES128Key(NSData * key,
                         NSData * salt,
                         uint32_t rounds)
{
    NSMutableData * data = [NSMutableData dataWithLength:kCCKeySizeAES128];
    
    return CCKeyDerivationPBKDF(    kCCPBKDF2,
                                    [key bytes],
                                    [key length],
                                    [salt bytes],
                                    [salt length],
                                    kCCHmacAlgSHA512,
                                    rounds,
                                    [data mutableBytes],
                                    kCCKeySizeAES128
            ) == errSecSuccess
                ? data : nil;
}


NSData * aes(NSData *    data,
             NSData *    key,
             CCOperation operation,
             CCOptions   options)
{
    uint32_t const data_length  = (uint32_t) [data length];
    uint32_t const out_capacity = (int)(data_length / kCCBlockSizeAES128 + 1) * kCCBlockSizeAES128;
    
    NSMutableData * output = [NSMutableData dataWithLength:out_capacity];

    size_t bytes_written;
    
    CCCryptorStatus ccStatus = CCCrypt(     operation, kCCAlgorithmAES128, options,
                                            (char const *)  [key bytes], [key length],
                                            NULL, // Initialization Vector (IV)
                                            (void const *)  [data bytes], data_length,
                                            (void *)        [output mutableBytes],
                                            out_capacity,
                                            &bytes_written
                                       );
    
    if (bytes_written < out_capacity)
        [output setLength:bytes_written];
    
    return ccStatus == kCCSuccess ? data : nil;
}
