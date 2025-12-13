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
      // US Regions
      [[MSTS3Region alloc] initWithIdentifier:@"us-east-2"
                                  displayName:@"US East (Ohio)"],
      [[MSTS3Region alloc] initWithIdentifier:@"us-east-1"
                                  displayName:@"US East (N. Virginia)"],
      [[MSTS3Region alloc] initWithIdentifier:@"us-west-1"
                                  displayName:@"US West (N. California)"],
      [[MSTS3Region alloc] initWithIdentifier:@"us-west-2"
                                  displayName:@"US West (Oregon)"],
      
      // Africa
      [[MSTS3Region alloc] initWithIdentifier:@"af-south-1"
                                  displayName:@"Africa (Cape Town)"],
      
      // Asia Pacific
      [[MSTS3Region alloc] initWithIdentifier:@"ap-east-1"
                                  displayName:@"Asia Pacific (Hong Kong)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-south-2"
                                  displayName:@"Asia Pacific (Hyderabad)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-3"
                                  displayName:@"Asia Pacific (Jakarta)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-5"
                                  displayName:@"Asia Pacific (Malaysia)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-4"
                                  displayName:@"Asia Pacific (Melbourne)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-south-1"
                                  displayName:@"Asia Pacific (Mumbai)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-6"
                                  displayName:@"Asia Pacific (New Zealand)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-northeast-3"
                                  displayName:@"Asia Pacific (Osaka)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-northeast-2"
                                  displayName:@"Asia Pacific (Seoul)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-1"
                                  displayName:@"Asia Pacific (Singapore)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-2"
                                  displayName:@"Asia Pacific (Sydney)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-east-2"
                                  displayName:@"Asia Pacific (Taipei)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-southeast-7"
                                  displayName:@"Asia Pacific (Thailand)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ap-northeast-1"
                                  displayName:@"Asia Pacific (Tokyo)"],
      
      // Canada
      [[MSTS3Region alloc] initWithIdentifier:@"ca-central-1"
                                  displayName:@"Canada (Central)"],
      [[MSTS3Region alloc] initWithIdentifier:@"ca-west-1"
                                  displayName:@"Canada West (Calgary)"],
      
      // Europe
      [[MSTS3Region alloc] initWithIdentifier:@"eu-central-1"
                                  displayName:@"Europe (Frankfurt)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-west-1"
                                  displayName:@"Europe (Ireland)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-west-2"
                                  displayName:@"Europe (London)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-south-1"
                                  displayName:@"Europe (Milan)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-west-3"
                                  displayName:@"Europe (Paris)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-south-2"
                                  displayName:@"Europe (Spain)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-north-1"
                                  displayName:@"Europe (Stockholm)"],
      [[MSTS3Region alloc] initWithIdentifier:@"eu-central-2"
                                  displayName:@"Europe (Zurich)"],
      
      // Israel
      [[MSTS3Region alloc] initWithIdentifier:@"il-central-1"
                                  displayName:@"Israel (Tel Aviv)"],
      
      // Mexico
      [[MSTS3Region alloc] initWithIdentifier:@"mx-central-1"
                                  displayName:@"Mexico (Central)"],
      
      // Middle East
      [[MSTS3Region alloc] initWithIdentifier:@"me-south-1"
                                  displayName:@"Middle East (Bahrain)"],
      [[MSTS3Region alloc] initWithIdentifier:@"me-central-1"
                                  displayName:@"Middle East (UAE)"],
      
      // South America
      [[MSTS3Region alloc] initWithIdentifier:@"sa-east-1"
                                  displayName:@"South America (São Paulo)"],
      
      // AWS GovCloud
      [[MSTS3Region alloc] initWithIdentifier:@"us-gov-east-1"
                                  displayName:@"AWS GovCloud (US-East)"],
      [[MSTS3Region alloc] initWithIdentifier:@"us-gov-west-1"
                                  displayName:@"AWS GovCloud (US-West)"]
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
                                  displayName:@"US East 1 (Fixed)"]
    ];

  case MSTS3ProviderTypeCloudflareR2:
    return @[ [[MSTS3Region alloc] initWithIdentifier:@"auto"
                                          displayName:@"Auto"] ];

  case MSTS3ProviderTypeBackblazeB2:
    return @[];

  case MSTS3ProviderTypeMinIO:
    return @[ [[MSTS3Region alloc] initWithIdentifier:@"us-east-1"
                                          displayName:@"US East 1 (Default)"] ];

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
  case MSTS3ProviderTypeMinIO:
    return @"MinIO";
  case MSTS3ProviderTypeCustom:
    return @"Generic S3";
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
  case MSTS3ProviderTypeMinIO:
    return @"us-east-1";
  case MSTS3ProviderTypeCustom:
    return @"us-east-1";
  }
  return @"us-east-1";
}

@end
