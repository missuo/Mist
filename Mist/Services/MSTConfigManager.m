//
//  MSTConfigManager.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTConfigManager.h"
#import "MSTConstants.h"
#import "MSTS3HostConfig.h"
#import "MSTiCloudSyncManager.h"

@interface MSTConfigManager ()

@property(nonatomic, strong)
    NSMutableArray<MSTS3HostConfig *> *mutableHostConfigs;
@property(nonatomic, strong) NSUserDefaults *userDefaults;
@property(nonatomic, strong) MSTiCloudSyncManager *iCloudSyncManager;

@end

@implementation MSTConfigManager

+ (MSTConfigManager *)sharedManager {
  static MSTConfigManager *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[MSTConfigManager alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    NSString *suiteName = kMSTAppGroupIdentifier;
    NSUserDefaults *sharedDefaults =
        [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    _userDefaults = sharedDefaults ?: [NSUserDefaults standardUserDefaults];
    [self migrateFromStandardDefaultsIfNeeded];

    _iCloudSyncManager = [MSTiCloudSyncManager sharedManager];
    _mutableHostConfigs = [NSMutableArray array];
    _outputFormat = MSTOutputFormatURL;
    _compressFactor = 0; // 0 = no compression by default
    _removeEXIF = NO;
    [self loadConfigs];
    
    // Observe iCloud changes
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleiCloudDataChange:)
               name:MSTiCloudDataDidChangeNotification
             object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Properties

- (NSArray<MSTS3HostConfig *> *)hostConfigs {
  return [self.mutableHostConfigs copy];
}

- (BOOL)iCloudSyncEnabled {
  return self.iCloudSyncManager.iCloudSyncEnabled;
}

- (void)setICloudSyncEnabled:(BOOL)iCloudSyncEnabled {
  BOOL wasEnabled = self.iCloudSyncManager.iCloudSyncEnabled;
  self.iCloudSyncManager.iCloudSyncEnabled = iCloudSyncEnabled;
  
  if (iCloudSyncEnabled && !wasEnabled) {
    // First time enabling iCloud sync
    NSLog(@"[Config] Enabling iCloud sync for the first time");
    
    // First, upload local data to iCloud
    [self syncToiCloud];
    NSLog(@"[Config] Uploaded local configs to iCloud");
    
    // Then, check if iCloud has newer data and load it
    // This handles the case where iCloud already has data from another device
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), 
                   dispatch_get_main_queue(), ^{
      NSLog(@"[Config] Checking for existing iCloud data...");
      [self loadFromiCloudIfAvailable];
      
      // Notify UI to refresh
      [[NSNotificationCenter defaultCenter]
          postNotificationName:MSTConfigDidChangeNotification
                        object:nil];
    });
  }
}

- (BOOL)iCloudAvailable {
  return self.iCloudSyncManager.iCloudAvailable;
}

#pragma mark - Host Config Management

- (void)addHostConfig:(MSTS3HostConfig *)config {
  [self.mutableHostConfigs addObject:config];

  // If this is the first config, set it as default
  if (self.mutableHostConfigs.count == 1) {
    config.isDefault = YES;
    self.defaultHost = config;
  }

  [self saveConfigs];
  [[NSNotificationCenter defaultCenter]
      postNotificationName:MSTConfigDidChangeNotification
                    object:nil];
}

- (void)removeHostConfig:(MSTS3HostConfig *)config {
  [self.mutableHostConfigs removeObject:config];

  // If we removed the default, set a new default
  if (config.isDefault && self.mutableHostConfigs.count > 0) {
    MSTS3HostConfig *newDefault = self.mutableHostConfigs.firstObject;
    newDefault.isDefault = YES;
    self.defaultHost = newDefault;
  } else if (self.mutableHostConfigs.count == 0) {
    self.defaultHost = nil;
  }

  [self saveConfigs];
  [[NSNotificationCenter defaultCenter]
      postNotificationName:MSTConfigDidChangeNotification
                    object:nil];
}

- (void)updateHostConfig:(MSTS3HostConfig *)config {
  NSUInteger index = [self.mutableHostConfigs
      indexOfObjectPassingTest:^BOOL(MSTS3HostConfig *obj, NSUInteger idx,
                                     BOOL *stop) {
        return [obj.identifier isEqualToString:config.identifier];
      }];

  if (index != NSNotFound) {
    self.mutableHostConfigs[index] = config;
  }

  [self saveConfigs];
  [[NSNotificationCenter defaultCenter]
      postNotificationName:MSTConfigDidChangeNotification
                    object:nil];
}

- (nullable MSTS3HostConfig *)hostConfigWithIdentifier:(NSString *)identifier {
  for (MSTS3HostConfig *config in self.mutableHostConfigs) {
    if ([config.identifier isEqualToString:identifier]) {
      return config;
    }
  }
  return nil;
}

- (void)setDefaultHostWithIdentifier:(NSString *)identifier {
  for (MSTS3HostConfig *config in self.mutableHostConfigs) {
    if ([config.identifier isEqualToString:identifier]) {
      // Clear old default
      for (MSTS3HostConfig *c in self.mutableHostConfigs) {
        c.isDefault = NO;
      }
      config.isDefault = YES;
      self.defaultHost = config;
      break;
    }
  }

  [self saveConfigs];
  [[NSNotificationCenter defaultCenter]
      postNotificationName:MSTConfigDidChangeNotification
                    object:nil];
}

#pragma mark - Persistence

- (void)saveConfigs {
  // Save host configs as array of dictionaries
  NSMutableArray *configDicts = [NSMutableArray array];
  for (MSTS3HostConfig *config in self.mutableHostConfigs) {
    [configDicts addObject:[config toDictionary]];
  }
  [self.userDefaults setObject:configDicts forKey:kMSTHostConfigs];

  // Save default host ID
  if (self.defaultHost) {
    [self.userDefaults setObject:self.defaultHost.identifier
                           forKey:kMSTDefaultHostId];
  } else {
    [self.userDefaults removeObjectForKey:kMSTDefaultHostId];
  }

  // Save other settings
  [self.userDefaults setInteger:self.outputFormat forKey:kMSTOutputFormat];
  [self.userDefaults setInteger:self.compressFactor forKey:kMSTCompressFactor];
  [self.userDefaults setBool:self.removeEXIF forKey:kMSTRemoveEXIF];

  [self.userDefaults synchronize];
  
  // Sync to iCloud if enabled
  [self syncToiCloud];
}

- (void)loadConfigs {
  // Try to load from iCloud first if enabled
  if (self.iCloudSyncEnabled && self.iCloudAvailable) {
    [self loadFromiCloudIfAvailable];
  }
  
  // Load host configs from local storage
  NSArray *configDicts = [self.userDefaults arrayForKey:kMSTHostConfigs];
  [self.mutableHostConfigs removeAllObjects];

  for (NSDictionary *dict in configDicts) {
    MSTS3HostConfig *config = [MSTS3HostConfig configFromDictionary:dict];
    if (config) {
      [self.mutableHostConfigs addObject:config];
    }
  }

  // Load default host
  NSString *defaultHostId = [self.userDefaults stringForKey:kMSTDefaultHostId];
  if (defaultHostId) {
    self.defaultHost = [self hostConfigWithIdentifier:defaultHostId];
  } else if (self.mutableHostConfigs.count > 0) {
    self.defaultHost = self.mutableHostConfigs.firstObject;
    self.defaultHost.isDefault = YES;
  }

  // Load other settings
  if ([self.userDefaults objectForKey:kMSTOutputFormat]) {
    self.outputFormat = [self.userDefaults integerForKey:kMSTOutputFormat];
  }

  if ([self.userDefaults objectForKey:kMSTCompressFactor]) {
    self.compressFactor = [self.userDefaults integerForKey:kMSTCompressFactor];
  }
  
  if ([self.userDefaults objectForKey:kMSTRemoveEXIF]) {
    self.removeEXIF = [self.userDefaults boolForKey:kMSTRemoveEXIF];
  }
}

- (void)migrateFromStandardDefaultsIfNeeded {
  if (!self.userDefaults || self.userDefaults == [NSUserDefaults standardUserDefaults]) {
    return;
  }

  // If shared defaults already contain data, skip migration
  if ([self.userDefaults objectForKey:kMSTHostConfigs] ||
      [self.userDefaults objectForKey:kMSTDefaultHostId] ||
      [self.userDefaults objectForKey:kMSTOutputFormat] ||
      [self.userDefaults objectForKey:kMSTCompressFactor] ||
      [self.userDefaults objectForKey:kMSTRemoveEXIF]) {
    return;
  }

  NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
  NSArray *configDicts = [standardDefaults arrayForKey:kMSTHostConfigs];
  NSString *defaultHostId = [standardDefaults stringForKey:kMSTDefaultHostId];
  NSNumber *outputFormat = [standardDefaults objectForKey:kMSTOutputFormat];
  NSNumber *compressFactor = [standardDefaults objectForKey:kMSTCompressFactor];

  if (!configDicts && !defaultHostId && !outputFormat && !compressFactor) {
    return;
  }

  if (configDicts) {
    [self.userDefaults setObject:configDicts forKey:kMSTHostConfigs];
  }
  if (defaultHostId) {
    [self.userDefaults setObject:defaultHostId forKey:kMSTDefaultHostId];
  }
  if (outputFormat) {
    [self.userDefaults setObject:outputFormat forKey:kMSTOutputFormat];
  }
  if (compressFactor) {
    [self.userDefaults setObject:compressFactor forKey:kMSTCompressFactor];
  }

  [self.userDefaults synchronize];
}

#pragma mark - URL Formatting

- (NSString *)formatURL:(NSString *)url {
  switch (self.outputFormat) {
  case MSTOutputFormatMarkdown:
    return [NSString stringWithFormat:@"![image](%@)", url];
  case MSTOutputFormatHTML:
    return [NSString stringWithFormat:@"<img src=\"%@\" />", url];
  case MSTOutputFormatUBB:
    return [NSString stringWithFormat:@"[img]%@[/img]", url];
  case MSTOutputFormatURL:
  default:
    return url;
  }
}

#pragma mark - iCloud Sync

- (void)syncToiCloud {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return;
  }
  
  // Sync host configs
  NSMutableArray *configDicts = [NSMutableArray array];
  for (MSTS3HostConfig *config in self.mutableHostConfigs) {
    [configDicts addObject:[config toDictionary]];
  }
  [self.iCloudSyncManager syncHostConfigs:configDicts];
  
  // Sync default host ID
  [self.iCloudSyncManager syncDefaultHostId:self.defaultHost.identifier];
  
  // Sync other settings
  [self.iCloudSyncManager syncOutputFormat:self.outputFormat];
  [self.iCloudSyncManager syncCompressFactor:self.compressFactor];
  [self.iCloudSyncManager syncRemoveEXIF:self.removeEXIF];
}

- (void)loadFromiCloudIfAvailable {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return;
  }
  
  NSLog(@"[Config] Loading data from iCloud...");
  BOOL hasCloudData = NO;
  
  // Load host configs from iCloud
  NSArray *cloudConfigDicts = [self.iCloudSyncManager getHostConfigs];
  if (cloudConfigDicts && cloudConfigDicts.count > 0) {
    NSLog(@"[Config] Found %lu host configs in iCloud", (unsigned long)cloudConfigDicts.count);
    hasCloudData = YES;
    
    // Always use iCloud data as source of truth
    [self.mutableHostConfigs removeAllObjects];
    for (NSDictionary *dict in cloudConfigDicts) {
      MSTS3HostConfig *config = [MSTS3HostConfig configFromDictionary:dict];
      if (config) {
        [self.mutableHostConfigs addObject:config];
      }
    }
    
    // Save to local storage
    [self.userDefaults setObject:cloudConfigDicts forKey:kMSTHostConfigs];
    NSLog(@"[Config] Updated local storage with %lu iCloud host configs", 
          (unsigned long)self.mutableHostConfigs.count);
  } else {
    NSLog(@"[Config] No host configs found in iCloud");
  }
  
  // Load default host ID from iCloud
  NSString *cloudDefaultHostId = [self.iCloudSyncManager getDefaultHostId];
  if (cloudDefaultHostId) {
    NSLog(@"[Config] Found default host ID in iCloud: %@", cloudDefaultHostId);
    hasCloudData = YES;
    self.defaultHost = [self hostConfigWithIdentifier:cloudDefaultHostId];
    if (self.defaultHost) {
      self.defaultHost.isDefault = YES;
      [self.userDefaults setObject:cloudDefaultHostId forKey:kMSTDefaultHostId];
    }
  }
  
  // Load output format from iCloud
  NSNumber *cloudOutputFormat = [self.iCloudSyncManager getOutputFormat];
  if (cloudOutputFormat) {
    hasCloudData = YES;
    self.outputFormat = [cloudOutputFormat integerValue];
    [self.userDefaults setInteger:self.outputFormat forKey:kMSTOutputFormat];
  }
  
  // Load compress factor from iCloud
  NSNumber *cloudCompressFactor = [self.iCloudSyncManager getCompressFactor];
  if (cloudCompressFactor) {
    hasCloudData = YES;
    self.compressFactor = [cloudCompressFactor integerValue];
    [self.userDefaults setInteger:self.compressFactor forKey:kMSTCompressFactor];
  }
  
  // Load remove EXIF from iCloud
  NSNumber *cloudRemoveEXIF = [self.iCloudSyncManager getRemoveEXIF];
  if (cloudRemoveEXIF) {
    hasCloudData = YES;
    self.removeEXIF = [cloudRemoveEXIF boolValue];
    [self.userDefaults setBool:self.removeEXIF forKey:kMSTRemoveEXIF];
  }
  
  [self.userDefaults synchronize];
  
  if (hasCloudData) {
    NSLog(@"[Config] Successfully loaded data from iCloud");
  } else {
    NSLog(@"[Config] No data found in iCloud yet - waiting for initial sync");
  }
}

- (void)handleiCloudDataChange:(NSNotification *)notification {
  if (!self.iCloudSyncEnabled) {
    return;
  }
  
  NSLog(@"[Config] Handling iCloud data change notification");
  
  NSDictionary *userInfo = notification.userInfo;
  NSNumber *changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey];
  
  if (changeReason) {
    NSInteger reason = [changeReason integerValue];
    
    if (reason == NSUbiquitousKeyValueStoreInitialSyncChange) {
      NSLog(@"[Config] Initial sync from iCloud");
    } else if (reason == NSUbiquitousKeyValueStoreServerChange) {
      NSLog(@"[Config] Server change from iCloud");
    } else if (reason == NSUbiquitousKeyValueStoreAccountChange) {
      NSLog(@"[Config] iCloud account changed");
    }
  }
  
  // Always reload from iCloud - it's the source of truth
  [self loadFromiCloudIfAvailable];
  
  // Post notification that config changed
  [[NSNotificationCenter defaultCenter]
      postNotificationName:MSTConfigDidChangeNotification
                    object:nil];
}

@end
