//
//  MSTS3HostConfig.h
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTS3Region.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSTS3HostConfig : NSObject <NSCoding, NSSecureCoding>

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, assign) MSTS3ProviderType providerType;
@property(nonatomic, copy) NSString *region;
@property(nonatomic, copy) NSString *endpoint;
@property(nonatomic, copy) NSString *bucket;
@property(nonatomic, copy) NSString *accessKey;
@property(nonatomic, copy) NSString *secretKey;
@property(nonatomic, copy) NSString *smmsToken;
@property(nonatomic, copy) NSString *domain;
@property(nonatomic, copy) NSString *saveKeyPath;
@property(nonatomic, copy) NSString *acl;
@property(nonatomic, assign) BOOL shortLinkEnabled;
@property(nonatomic, assign) BOOL isDefault;

- (instancetype)init;
- (instancetype)initWithIdentifier:(NSString *)identifier
    NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithDictionary:(NSDictionary *)dict;

- (NSDictionary *)toDictionary;

- (BOOL)isCustomEndpoint;
- (NSString *)baseURL;
- (NSString *)computedEndpoint;

- (instancetype)copyWithNewIdentifier;

+ (nullable MSTS3HostConfig *)configFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
