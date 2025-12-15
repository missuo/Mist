//
//  MSTCryptoHelper.m
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import "MSTCryptoHelper.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

@implementation MSTCryptoHelper

+ (NSString *)sha256HashHex:(NSData *)data {
  unsigned char hash[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, hash);

  NSMutableString *result =
      [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [result appendFormat:@"%02x", hash[i]];
  }
  return result;
}

+ (NSString *)sha256HashHexString:(NSString *)string {
  return [self sha256HashHex:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

+ (NSData *)hmacSHA256:(NSString *)data withKey:(NSString *)key {
  const char *cKey = [key cStringUsingEncoding:NSUTF8StringEncoding];
  const char *cData = [data cStringUsingEncoding:NSUTF8StringEncoding];
  unsigned char result[CC_SHA256_DIGEST_LENGTH];

  CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), result);

  return [NSData dataWithBytes:result length:CC_SHA256_DIGEST_LENGTH];
}

+ (NSData *)hmacSHA256Data:(NSString *)data withKeyData:(NSData *)keyData {
  const char *cData = [data cStringUsingEncoding:NSUTF8StringEncoding];
  unsigned char result[CC_SHA256_DIGEST_LENGTH];

  CCHmac(kCCHmacAlgSHA256, keyData.bytes, keyData.length, cData, strlen(cData),
         result);

  return [NSData dataWithBytes:result length:CC_SHA256_DIGEST_LENGTH];
}

+ (NSString *)hmacSHA256HexData:(NSString *)data withKeyData:(NSData *)keyData {
  NSData *hmacData = [self hmacSHA256Data:data withKeyData:keyData];

  NSMutableString *result =
      [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  const unsigned char *bytes = hmacData.bytes;
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [result appendFormat:@"%02x", bytes[i]];
  }
  return result;
}

@end
