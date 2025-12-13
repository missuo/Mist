//
//  MSTConfigManager.h
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import <Foundation/Foundation.h>
#import "MSTConstants.h"

@class MSTS3HostConfig;

NS_ASSUME_NONNULL_BEGIN

@interface MSTConfigManager : NSObject

@property (nonatomic, strong, readonly, class) MSTConfigManager *sharedManager;

@property (nonatomic, strong, readonly) NSArray<MSTS3HostConfig *> *hostConfigs;
@property (nonatomic, strong, nullable) MSTS3HostConfig *defaultHost;
@property (nonatomic, assign) MSTOutputFormat outputFormat;
@property (nonatomic, assign) NSInteger compressFactor; // 0 = no compression, 10-90 = quality
@property (nonatomic, assign) BOOL removeEXIF;

- (void)addHostConfig:(MSTS3HostConfig *)config;
- (void)removeHostConfig:(MSTS3HostConfig *)config;
- (void)updateHostConfig:(MSTS3HostConfig *)config;
- (nullable MSTS3HostConfig *)hostConfigWithIdentifier:(NSString *)identifier;

- (void)setDefaultHostWithIdentifier:(NSString *)identifier;
- (void)saveConfigs;
- (void)loadConfigs;

- (NSString *)formatURL:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
