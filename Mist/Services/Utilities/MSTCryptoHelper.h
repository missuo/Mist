//
//  MSTCryptoHelper.h
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSTCryptoHelper : NSObject

+ (NSString *)sha256HashHex:(NSData *)data;
+ (NSString *)sha256HashHexString:(NSString *)string;
+ (NSData *)hmacSHA256:(NSString *)data withKey:(NSString *)key;
+ (NSData *)hmacSHA256Data:(NSString *)data withKeyData:(NSData *)keyData;
+ (NSString *)hmacSHA256HexData:(NSString *)data withKeyData:(NSData *)keyData;

@end

NS_ASSUME_NONNULL_END
