//
//  MSTS3Region.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTS3Region.h"

@implementation MSTS3Region

- (instancetype)initWithIdentifier:(NSString *)identifier
                       displayName:(NSString *)displayName {
  self = [super init];
  if (self) {
    _identifier = [identifier copy];
    _displayName = [displayName copy];
  }
  return self;
}

- (NSString *)endpoint {
  return [NSString stringWithFormat:@"s3.%@.amazonaws.com", self.identifier];
}

+ (NSArray<MSTS3Region *> *)allRegions {
  static NSArray<MSTS3Region *> *regions = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    regions = @[
      [[MSTS3Region alloc] initWithIdentifier:@"us-east-1"
                                  displayName:@"US East (N. Virginia)"],
      [[MSTS3Region alloc] initWithIdentifier:@"us-east-2"
                                  displayName:@"US East (Ohio)"],
      [[MSTS3Region alloc] initWithIdentifier:@"us-west-1"
                                  displayName:@"US West (N. California)"],
      [[MSTS3Region alloc] initWithIdentifier:@"us-west-2"
                                  displayName:@"US West (Oregon)"],
      [[MSTS3Region alloc] initWithIdentifier:@"af-south-1"
                                  displayName:@"Africa (Cape Town)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-east-1"
                                  displayName:@"Asia Pacific (Hong Kong)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-south-1"
                                  displayName:@"Asia Pacific (Mumbai)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-south-2"
                                  displayName:@"Asia Pacific (Hyderabad)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-northeast-1"
                                  displayName:@"Asia Pacific (Tokyo)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-northeast-2"
                                  displayName:@"Asia Pacific (Seoul)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-northeast-3"
                                  displayName:@"Asia Pacific (Osaka)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-1"
                                  displayName:@"Asia Pacific (Singapore)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-2"
                                  displayName:@"Asia Pacific (Sydney)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-3"
                                  displayName:@"Asia Pacific (Jakarta)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-4"
                                  displayName:@"Asia Pacific (Melbourne)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ca-central-1"
                                  displayName:@"Canada (Central)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ca-west-1"
                                  displayName:@"Canada West (Calgary)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-central-1"
                                  displayName:@"Europe (Frankfurt)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-central-2"
                                  displayName:@"Europe (Zurich)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-west-1"
                                  displayName:@"Europe (Ireland)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-west-2"
                                  displayName:@"Europe (London)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-west-3"
                                  displayName:@"Europe (Paris)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-north-1"
                                  displayName:@"Europe (Stockholm)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-south-1"
                                  displayName:@"Europe (Milan)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-south-2"
                                  displayName:@"Europe (Spain)"],
      [[MSTS3Region alloc] initWithIdentifier:@"il-central-1"
                                  displayName:@"Israel (Tel Aviv)"],
      [[MSTS3Region alloc] initWithIdentifier:@"me-central-1"
                                  displayName:@"Middle East (UAE)"],
      [[MSTS3Region alloc] initWithIdentifier:@"me-south-1"
                                  displayName:@"Middle East (Bahrain)"],
      [[MSTS3Region alloc] initWithIdentifier:@"sa-east-1"
                                  displayName:@"South America (São Paulo)"]
    ];
  });
  return regions;
}

+ (nullable MSTS3Region *)regionWithIdentifier:(NSString *)identifier {
  for (MSTS3Region *region in [self allRegions]) {
    if ([region.identifier isEqualToString:identifier]) {
      return region;
    }
  }
  return nil;
}

+ (NSString *)endpointForRegion:(NSString *)regionIdentifier {
  return [NSString
      stringWithFormat:@"https://s3.%@.amazonaws.com", regionIdentifier];
}

+ (NSArray<MSTS3Region *> *)regionsForProvider:(MSTS3ProviderType)provider {
  switch (provider) {
  case MSTS3ProviderTypeAmazonS3:
    return [self allRegions];

  case MSTS3ProviderTypeWasabi:
    return @[
      [[MSTS3Region alloc] initWithIdentifier:@"us-east-1"
                                  displayName:@"US East 1 (N. Virginia)"],
      [[MSTS3Region alloc] initWithIdentifier:@"us-east-2"
                                  displayName:@"US East 2 (N. Virginia)"],
      [[MSTS3Region alloc] initWithIdentifier:@"us-central-1"
                                  displayName:@"US Central 1 (Texas)"],
      [[MSTS3Region alloc] initWithIdentifier:@"us-west-1"
                                  displayName:@"US West 1 (Oregon)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ca-central-1"
                                  displayName:@"Canada (Toronto)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-central-1"
                                  displayName:@"EU Central 1 (Amsterdam)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-central-2"
                                  displayName:@"EU Central 2 (Frankfurt)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-west-1"
                                  displayName:@"EU West 1 (London)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-west-2"
                                  displayName:@"EU West 2 (Paris)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-northeast-1"
                                  displayName:@"AP Northeast 1 (Tokyo)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-northeast-2"
                                  displayName:@"AP Northeast 2 (Osaka)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-1"
                                  displayName:@"AP Southeast 1 (Singapore)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-2"
                                  displayName:@"AP Southeast 2 (Sydney)"]
    ];

  case MSTS3ProviderTypeCloudflareR2:
    return @[ [[MSTS3Region alloc] initWithIdentifier:@"auto"
                                          displayName:@"Auto"] ];

  case MSTS3ProviderTypeBackblazeB2:
    return @[];

  case MSTS3ProviderTypeCustom:
    return @[ [[MSTS3Region alloc] initWithIdentifier:@"us-east-1"
                                          displayName:@"US East 1 (Default)"] ];
  }
  return @[];
}

+ (NSString *)displayNameForProvider:(MSTS3ProviderType)provider {
  switch (provider) {
  case MSTS3ProviderTypeAmazonS3:
    return @"Amazon S3";
  case MSTS3ProviderTypeWasabi:
    return @"Wasabi";
  case MSTS3ProviderTypeCloudflareR2:
    return @"Cloudflare R2";
  case MSTS3ProviderTypeBackblazeB2:
    return @"Backblaze B2";
  case MSTS3ProviderTypeCustom:
    return @"Custom S3";
  }
  return @"Unknown";
}

+ (NSString *)defaultRegionForProvider:(MSTS3ProviderType)provider {
  switch (provider) {
  case MSTS3ProviderTypeAmazonS3:
    return @"us-east-1";
  case MSTS3ProviderTypeWasabi:
    return @"us-east-1";
  case MSTS3ProviderTypeCloudflareR2:
    return @"auto";
  case MSTS3ProviderTypeBackblazeB2:
    return @"";
  case MSTS3ProviderTypeCustom:
    return @"us-east-1";
  }
  return @"us-east-1";
}

@end
