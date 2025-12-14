//
//  MSTiCloudSyncManager.h
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSTiCloudSyncManager : NSObject

@property (nonatomic, strong, readonly, class) MSTiCloudSyncManager *sharedManager;

@property (nonatomic, assign) BOOL iCloudSyncEnabled;
@property (nonatomic, assign, readonly) BOOL iCloudAvailable;
@property (nonatomic, strong, readonly, nullable) NSDate *lastSyncDate;

- (void)syncHostConfigs:(NSArray<NSDictionary *> *)configs;
- (nullable NSArray<NSDictionary *> *)getHostConfigs;

- (void)syncDefaultHostId:(nullable NSString *)hostId;
- (nullable NSString *)getDefaultHostId;

- (void)syncOutputFormat:(NSInteger)format;
- (nullable NSNumber *)getOutputFormat;

- (void)syncCompressFactor:(NSInteger)factor;
- (nullable NSNumber *)getCompressFactor;

- (void)syncRemoveEXIF:(BOOL)removeEXIF;
- (nullable NSNumber *)getRemoveEXIF;

- (void)startObserving;
- (void)stopObserving;

- (void)updateLastSyncDate;

- (void)printStatus;
- (void)debugDumpAllKeys;

@end

NS_ASSUME_NONNULL_END
