//
//  MSTiCloudSyncManager.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTiCloudSyncManager.h"
#import "MSTConstants.h"

static NSString * const kMSTiCloudSyncEnabled = @"iCloudSyncEnabled";
static NSString * const kMSTiCloudLastSyncDate = @"iCloudLastSyncDate";
static NSString * const kMSTiCloudHostConfigs = @"iCloudHostConfigs";
static NSString * const kMSTiCloudDefaultHostId = @"iCloudDefaultHostId";
static NSString * const kMSTiCloudOutputFormat = @"iCloudOutputFormat";
static NSString * const kMSTiCloudCompressFactor = @"iCloudCompressFactor";
static NSString * const kMSTiCloudRemoveEXIF = @"iCloudRemoveEXIF";

@interface MSTiCloudSyncManager ()

@property (nonatomic, strong) NSUbiquitousKeyValueStore *cloudStore;
@property (nonatomic, assign, readwrite) BOOL iCloudAvailable;
@property (nonatomic, strong, readwrite, nullable) NSDate *lastSyncDate;

@end

@implementation MSTiCloudSyncManager

+ (MSTiCloudSyncManager *)sharedManager {
  static MSTiCloudSyncManager *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[MSTiCloudSyncManager alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _cloudStore = [NSUbiquitousKeyValueStore defaultStore];
    _iCloudAvailable = (_cloudStore != nil);
    
    NSLog(@"[iCloud Sync] Initializing...");
    NSLog(@"[iCloud Sync] iCloud Available: %@", _iCloudAvailable ? @"YES" : @"NO");
    
    // Load sync enabled state from UserDefaults (not synced)
    _iCloudSyncEnabled = [[NSUserDefaults standardUserDefaults] 
                           boolForKey:kMSTiCloudSyncEnabled];
    
    NSLog(@"[iCloud Sync] Sync Enabled: %@", _iCloudSyncEnabled ? @"YES" : @"NO");
    
    // Load last sync date
    NSData *dateData = [[NSUserDefaults standardUserDefaults] objectForKey:kMSTiCloudLastSyncDate];
    if (dateData) {
      _lastSyncDate = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSDate class] fromData:dateData error:nil];
      if (_lastSyncDate) {
        NSLog(@"[iCloud Sync] Last sync: %@", _lastSyncDate);
      }
    }
    
    if (_iCloudAvailable) {
      [self startObserving];
      // Trigger initial sync
      BOOL syncResult = [_cloudStore synchronize];
      NSLog(@"[iCloud Sync] Initial synchronize result: %@", syncResult ? @"SUCCESS" : @"FAILED");
    } else {
      NSLog(@"[iCloud Sync] WARNING: iCloud is not available. User may not be signed in to iCloud.");
    }
  }
  return self;
}

- (void)dealloc {
  [self stopObserving];
}

#pragma mark - Sync Enabled

- (void)setICloudSyncEnabled:(BOOL)iCloudSyncEnabled {
  if (_iCloudSyncEnabled != iCloudSyncEnabled) {
    _iCloudSyncEnabled = iCloudSyncEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:iCloudSyncEnabled 
                                            forKey:kMSTiCloudSyncEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSLog(@"[iCloud Sync] Sync %@", iCloudSyncEnabled ? @"ENABLED" : @"DISABLED");
    
    if (iCloudSyncEnabled && _iCloudAvailable) {
      // Trigger sync when enabled
      BOOL syncResult = [self.cloudStore synchronize];
      NSLog(@"[iCloud Sync] Synchronize result: %@", syncResult ? @"SUCCESS" : @"FAILED");
    }
  }
}

#pragma mark - Observation

- (void)startObserving {
  if (!_iCloudAvailable) {
    return;
  }
  
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(cloudStoreDidChange:)
             name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
           object:_cloudStore];
}

- (void)stopObserving {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)cloudStoreDidChange:(NSNotification *)notification {
  if (!self.iCloudSyncEnabled) {
    return;
  }
  
  NSLog(@"[iCloud Sync] Cloud store did change notification received");
  
  NSDictionary *userInfo = notification.userInfo;
  NSNumber *changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey];
  NSArray *changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey];
  
  // changeReason can be:
  // NSUbiquitousKeyValueStoreServerChange
  // NSUbiquitousKeyValueStoreInitialSyncChange
  // NSUbiquitousKeyValueStoreQuotaViolationChange
  // NSUbiquitousKeyValueStoreAccountChange
  
  if (changeReason) {
    NSInteger reason = [changeReason integerValue];
    
    if (reason == NSUbiquitousKeyValueStoreServerChange) {
      NSLog(@"[iCloud Sync] Change reason: Server change");
      // Update last sync date when receiving data from server
      [self updateLastSyncDate];
    } else if (reason == NSUbiquitousKeyValueStoreInitialSyncChange) {
      NSLog(@"[iCloud Sync] Change reason: Initial sync");
      // Update last sync date on initial sync
      [self updateLastSyncDate];
    } else if (reason == NSUbiquitousKeyValueStoreQuotaViolationChange) {
      NSLog(@"[iCloud Sync] ERROR: iCloud quota exceeded");
      return;
    } else if (reason == NSUbiquitousKeyValueStoreAccountChange) {
      NSLog(@"[iCloud Sync] Change reason: iCloud account changed");
    }
  }
  
  if (changedKeys) {
    NSLog(@"[iCloud Sync] Changed keys: %@", changedKeys);
  }
  
  // Notify that iCloud data changed
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:MSTiCloudDataDidChangeNotification
                      object:nil
                    userInfo:userInfo];
  });
}

#pragma mark - Host Configs Sync

- (void)syncHostConfigs:(NSArray<NSDictionary *> *)configs {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return;
  }
  
  NSLog(@"[iCloud Sync] Syncing %lu host configs to iCloud", (unsigned long)configs.count);
  
  NSData *data = [NSJSONSerialization dataWithJSONObject:configs
                                                 options:0
                                                   error:nil];
  if (data) {
    [self.cloudStore setData:data forKey:kMSTiCloudHostConfigs];
    BOOL result = [self.cloudStore synchronize];
    NSLog(@"[iCloud Sync] Host configs sync result: %@", result ? @"SUCCESS" : @"FAILED");
    if (result) {
      [self updateLastSyncDate];
    }
  }
}

- (nullable NSArray<NSDictionary *> *)getHostConfigs {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return nil;
  }
  
  NSData *data = [self.cloudStore dataForKey:kMSTiCloudHostConfigs];
  if (data) {
    NSArray *configs = [NSJSONSerialization JSONObjectWithData:data
                                                       options:0
                                                         error:nil];
    return configs;
  }
  return nil;
}

#pragma mark - Default Host ID Sync

- (void)syncDefaultHostId:(nullable NSString *)hostId {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return;
  }
  
  if (hostId) {
    [self.cloudStore setString:hostId forKey:kMSTiCloudDefaultHostId];
  } else {
    [self.cloudStore removeObjectForKey:kMSTiCloudDefaultHostId];
  }
  [self.cloudStore synchronize];
}

- (nullable NSString *)getDefaultHostId {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return nil;
  }
  
  return [self.cloudStore stringForKey:kMSTiCloudDefaultHostId];
}

#pragma mark - Output Format Sync

- (void)syncOutputFormat:(NSInteger)format {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return;
  }
  
  [self.cloudStore setLongLong:format forKey:kMSTiCloudOutputFormat];
  [self.cloudStore synchronize];
}

- (nullable NSNumber *)getOutputFormat {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return nil;
  }
  
  id value = [self.cloudStore objectForKey:kMSTiCloudOutputFormat];
  if (value) {
    return @([self.cloudStore longLongForKey:kMSTiCloudOutputFormat]);
  }
  return nil;
}

#pragma mark - Compress Factor Sync

- (void)syncCompressFactor:(NSInteger)factor {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return;
  }
  
  [self.cloudStore setLongLong:factor forKey:kMSTiCloudCompressFactor];
  [self.cloudStore synchronize];
}

- (nullable NSNumber *)getCompressFactor {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return nil;
  }
  
  id value = [self.cloudStore objectForKey:kMSTiCloudCompressFactor];
  if (value) {
    return @([self.cloudStore longLongForKey:kMSTiCloudCompressFactor]);
  }
  return nil;
}

#pragma mark - Remove EXIF Sync

- (void)syncRemoveEXIF:(BOOL)removeEXIF {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return;
  }
  
  [self.cloudStore setBool:removeEXIF forKey:kMSTiCloudRemoveEXIF];
  [self.cloudStore synchronize];
}

- (nullable NSNumber *)getRemoveEXIF {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return nil;
  }
  
  id value = [self.cloudStore objectForKey:kMSTiCloudRemoveEXIF];
  if (value) {
    return @([self.cloudStore boolForKey:kMSTiCloudRemoveEXIF]);
  }
  return nil;
}

#pragma mark - Last Sync Date

- (void)updateLastSyncDate {
  self.lastSyncDate = [NSDate date];
  NSData *dateData = [NSKeyedArchiver archivedDataWithRootObject:self.lastSyncDate
                                           requiringSecureCoding:NO
                                                           error:nil];
  if (dateData) {
    [[NSUserDefaults standardUserDefaults] setObject:dateData forKey:kMSTiCloudLastSyncDate];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
  
  // Post notification that sync date changed
  [[NSNotificationCenter defaultCenter]
      postNotificationName:MSTiCloudDataDidChangeNotification
                    object:nil];
}

#pragma mark - Debug

- (void)printStatus {
  NSLog(@"========== iCloud Sync Status ==========");
  NSLog(@"iCloud Available: %@", self.iCloudAvailable ? @"YES ✓" : @"NO ✗");
  NSLog(@"Sync Enabled: %@", self.iCloudSyncEnabled ? @"YES ✓" : @"NO ✗");
  
  if (self.iCloudAvailable) {
    // Check if data exists in iCloud
    NSArray *hostConfigs = [self getHostConfigs];
    NSString *defaultHostId = [self getDefaultHostId];
    NSNumber *outputFormat = [self getOutputFormat];
    
    NSLog(@"Data in iCloud:");
    NSLog(@"  - Host Configs: %lu items", (unsigned long)(hostConfigs ? hostConfigs.count : 0));
    NSLog(@"  - Default Host ID: %@", defaultHostId ?: @"(none)");
    NSLog(@"  - Output Format: %@", outputFormat ? [outputFormat stringValue] : @"(none)");
  } else {
    NSLog(@"Possible reasons for iCloud unavailable:");
    NSLog(@"  1. User not signed in to iCloud");
    NSLog(@"  2. iCloud Drive not enabled");
    NSLog(@"  3. App doesn't have iCloud permission");
    NSLog(@"  4. Missing iCloud capability in Xcode");
  }
  NSLog(@"======================================");
}

@end
