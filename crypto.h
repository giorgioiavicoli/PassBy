#ifndef CRYPTO_H
#define CRYPTO_H

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>

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

        return [NSString stringWithString:hash];
    }
    return nil;
}

NSData * aes(
    NSData *    data,
    NSData *    key,
    CCOperation operation,
    CCOptions   options)
{
    uint32_t const data_length  = (uint32_t) [data length];
    uint32_t const out_capacity = (int)(data_length / kCCBlockSizeAES128 + 1) * kCCBlockSizeAES128;

    NSMutableData * output =
        [NSMutableData
            dataWithLength:out_capacity
        ];

    size_t bytes_written;

    CCCryptorStatus ccStatus = CCCrypt(
        operation, kCCAlgorithmAES128, options,
        (char const *)  [key bytes], [key length],
        [key bytes], // Initialization Vector (IV)
        (void const *)  [data bytes], data_length,
        (void *)        [output mutableBytes],
        out_capacity,
        &bytes_written
    );

    if (bytes_written < out_capacity)
        [output setLength:bytes_written];

    return ccStatus == kCCSuccess ? output : nil;
}

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

#endif // CRYPTO_H