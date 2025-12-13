//
//  MSTS3Region.h
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MSTS3ProviderType) {
  MSTS3ProviderTypeAmazonS3 = 0,
  MSTS3ProviderTypeWasabi,
  MSTS3ProviderTypeCloudflareR2,
  MSTS3ProviderTypeBackblazeB2,
  MSTS3ProviderTypeMinIO,
  MSTS3ProviderTypeCustom
};

@interface MSTS3Region : NSObject

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *displayName;
@property(nonatomic, copy, readonly) NSString *endpoint;

- (instancetype)initWithIdentifier:(NSString *)identifier
                       displayName:(NSString *)displayName;

+ (NSArray<MSTS3Region *> *)allRegions;
+ (NSArray<MSTS3Region *> *)regionsForProvider:(MSTS3ProviderType)provider;
+ (nullable MSTS3Region *)regionWithIdentifier:(NSString *)identifier;
+ (NSString *)endpointForRegion:(NSString *)regionIdentifier;
+ (NSString *)displayNameForProvider:(MSTS3ProviderType)provider;
+ (NSString *)defaultRegionForProvider:(MSTS3ProviderType)provider;

@end

NS_ASSUME_NONNULL_END
