//
//  MSTProviderFactory.h
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import <Foundation/Foundation.h>
#import "MSTUploadProvider.h"
#import "MSTS3Region.h"

@class MSTS3HostConfig;

NS_ASSUME_NONNULL_BEGIN

@interface MSTProviderFactory : NSObject

+ (id<MSTUploadProvider>)providerForConfig:(MSTS3HostConfig *)config;
+ (id<MSTUploadProvider>)providerForType:(MSTS3ProviderType)type;

@end

NS_ASSUME_NONNULL_END
