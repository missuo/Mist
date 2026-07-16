//
//  MSTProviderFactory.m
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import "MSTProviderFactory.h"
#import "MSTS3HostConfig.h"
#import "MSTS3Provider.h"
#import "MSTSEEProvider.h"

@implementation MSTProviderFactory

+ (id<MSTUploadProvider>)providerForConfig:(MSTS3HostConfig *)config {
  return [self providerForType:config.providerType];
}

+ (id<MSTUploadProvider>)providerForType:(MSTS3ProviderType)type {
  switch (type) {
    case MSTS3ProviderTypeSEE:
      return [[MSTSEEProvider alloc] init];

    case MSTS3ProviderTypeAmazonS3:
    case MSTS3ProviderTypeWasabi:
    case MSTS3ProviderTypeCloudflareR2:
    case MSTS3ProviderTypeBackblazeB2:
    case MSTS3ProviderTypeMinIO:
    case MSTS3ProviderTypeCustom:
    default:
      return [[MSTS3Provider alloc] init];
  }
}

@end
