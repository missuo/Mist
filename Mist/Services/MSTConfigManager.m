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
    _shortLinkDefaultDomain = @"s.ee";
    _shortLinkDomains = @[];
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

- (void)setCompressFactor:(NSInteger)compressFactor {
  // Only 10-90 enables compression. Anything else means off — this also
  // neutralizes the legacy default of 100 that old builds persisted to
  // UserDefaults/iCloud, which used to cause an unintended re-encode.
  if (compressFactor < 10 || compressFactor > 90) {
    compressFactor = 0;
  }
  _compressFactor = compressFactor;
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

    // Strategy: Check iCloud first, only upload local data if iCloud is empty
    // This prevents new devices from overwriting existing iCloud data with defaults

    // Immediately check if iCloud already has data
    NSArray *cloudConfigs = [self.iCloudSyncManager getHostConfigs];
    BOOL iCloudHasData = (cloudConfigs != nil && cloudConfigs.count > 0);

    if (iCloudHasData) {
      // iCloud already has data (from another device)
      NSLog(@"[Config] Found %lu existing configs in iCloud, loading them...",
            (unsigned long)cloudConfigs.count);
      [self loadFromiCloudIfAvailable];
    } else if (self.mutableHostConfigs.count > 0) {
      // iCloud is empty, but we have local configs - upload them
      NSLog(@"[Config] iCloud is empty, uploading %lu local configs...",
            (unsigned long)self.mutableHostConfigs.count);
      [self syncToiCloud];
    } else {
      // Both iCloud and local are empty - iCloud sync might still be in progress
      NSLog(@"[Config] No configs in iCloud or locally, will retry...");
    }

    // Schedule multiple retries for iCloud sync - initial sync can take time
    [self scheduleICloudRetryWithAttempt:1 maxAttempts:5];

    // Notify UI immediately
    [[NSNotificationCenter defaultCenter]
        postNotificationName:MSTConfigDidChangeNotification
                      object:nil];
  }
}

- (BOOL)iCloudAvailable {
  return self.iCloudSyncManager.iCloudAvailable;
}

- (void)scheduleICloudRetryWithAttempt:(NSInteger)attempt maxAttempts:(NSInteger)maxAttempts {
  if (!self.iCloudSyncEnabled || !self.iCloudAvailable) {
    return;
  }

  // Exponential backoff: 2s, 4s, 6s, 8s, 10s
  NSTimeInterval delay = attempt * 2.0;

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    if (!self.iCloudSyncEnabled) {
      return;
    }

    NSLog(@"[Config] iCloud retry attempt %ld/%ld", (long)attempt, (long)maxAttempts);

    // Check if we already have data loaded
    if (self.mutableHostConfigs.count > 0) {
      NSLog(@"[Config] Already have %lu configs, no need to retry",
            (unsigned long)self.mutableHostConfigs.count);
      if (!self.iCloudSyncManager.lastSyncDate) {
        [self.iCloudSyncManager updateLastSyncDate];
      }
      return;
    }

    // Try to load from iCloud
    [self loadFromiCloudIfAvailable];

    // Check if we got data
    if (self.mutableHostConfigs.count > 0) {
      NSLog(@"[Config] Successfully loaded %lu configs from iCloud on attempt %ld",
            (unsigned long)self.mutableHostConfigs.count, (long)attempt);
      [[NSNotificationCenter defaultCenter]
          postNotificationName:MSTConfigDidChangeNotification
                        object:nil];
    } else if (attempt < maxAttempts) {
      // Schedule next retry
      [self scheduleICloudRetryWithAttempt:attempt + 1 maxAttempts:maxAttempts];
    } else {
      // Max attempts reached
      NSLog(@"[Config] Max iCloud retry attempts reached, no data found");
      if (!self.iCloudSyncManager.lastSyncDate) {
        [self.iCloudSyncManager updateLastSyncDate];
      }
      [[NSNotificationCenter defaultCenter]
          postNotificationName:MSTConfigDidChangeNotification
                        object:nil];
    }
  });
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
  if (self.shortLinkAPIKey.length > 0) {
    [self.userDefaults setObject:self.shortLinkAPIKey forKey:kMSTShortLinkAPIKey];
  } else {
    [self.userDefaults removeObjectForKey:kMSTShortLinkAPIKey];
  }
  if (self.shortLinkDefaultDomain.length > 0) {
    [self.userDefaults setObject:self.shortLinkDefaultDomain forKey:kMSTShortLinkDefaultDomain];
  }
  if (self.shortLinkDomains) {
    [self.userDefaults setObject:self.shortLinkDomains forKey:kMSTShortLinkDomains];
  }

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

  NSString *apiKey = [self.userDefaults stringForKey:kMSTShortLinkAPIKey];
  if (apiKey) {
    self.shortLinkAPIKey = apiKey;
  }
  NSString *defaultDomain = [self.userDefaults stringForKey:kMSTShortLinkDefaultDomain];
  if (defaultDomain.length > 0) {
    self.shortLinkDefaultDomain = defaultDomain;
  }
  NSArray *domains = [self.userDefaults arrayForKey:kMSTShortLinkDomains];
  if ([domains isKindOfClass:[NSArray class]]) {
    self.shortLinkDomains = domains;
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

  // Sync host configs - copy array to avoid mutation during iteration
  NSArray *hostConfigsCopy;
  NSString *defaultHostId;
  @synchronized (self) {
    hostConfigsCopy = [self.mutableHostConfigs copy];
    defaultHostId = self.defaultHost.identifier;
  }

  NSMutableArray *configDicts = [NSMutableArray array];
  for (MSTS3HostConfig *config in hostConfigsCopy) {
    [configDicts addObject:[config toDictionary]];
  }
  [self.iCloudSyncManager syncHostConfigs:configDicts];

  // Sync default host ID (nil is safe)
  [self.iCloudSyncManager syncDefaultHostId:defaultHostId];

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

    // Parse configs first before modifying mutableHostConfigs
    NSMutableArray *parsedConfigs = [NSMutableArray array];
    for (NSDictionary *dict in cloudConfigDicts) {
      MSTS3HostConfig *config = [MSTS3HostConfig configFromDictionary:dict];
      if (config) {
        [parsedConfigs addObject:config];
      }
    }

    // Now safely update mutableHostConfigs
    @synchronized (self) {
      [self.mutableHostConfigs removeAllObjects];
      [self.mutableHostConfigs addObjectsFromArray:parsedConfigs];
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

  // Fallback: if no default host but we have configs, set first one as default
  if (!self.defaultHost && self.mutableHostConfigs.count > 0) {
    NSLog(@"[Config] No default host set, using first config as default");
    self.defaultHost = self.mutableHostConfigs.firstObject;
    self.defaultHost.isDefault = YES;
    [self.userDefaults setObject:self.defaultHost.identifier forKey:kMSTDefaultHostId];
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
    // Update last sync date since we successfully loaded data
    [self.iCloudSyncManager updateLastSyncDate];
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

#pragma mark - Import/Export

- (BOOL)exportConfigsToURL:(NSURL *)url error:(NSError **)error {
  // Build export dictionary
  NSMutableArray *configDicts = [NSMutableArray array];
  for (MSTS3HostConfig *config in self.mutableHostConfigs) {
    [configDicts addObject:[config toDictionary]];
  }

  NSDictionary *exportData = @{
    @"version" : @1,
    @"exportDate" : [[NSDate date] description],
    @"hosts" : configDicts,
    @"defaultHostId" : self.defaultHost.identifier ?: [NSNull null],
    @"settings" : @{
      @"outputFormat" : @(self.outputFormat),
      @"compressFactor" : @(self.compressFactor),
      @"removeEXIF" : @(self.removeEXIF),
      @"shortLinkAPIKey" : self.shortLinkAPIKey ?: @"",
      @"shortLinkDefaultDomain" : self.shortLinkDefaultDomain ?: @"s.ee",
      @"shortLinkDomains" : self.shortLinkDomains ?: @[]
    }
  };

  NSError *jsonError = nil;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportData
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&jsonError];
  if (!jsonData) {
    if (error) {
      *error = jsonError ?: [NSError errorWithDomain:@"MSTConfigError"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey : @"Failed to serialize config to JSON"}];
    }
    return NO;
  }

  NSError *writeError = nil;
  BOOL success = [jsonData writeToURL:url options:NSDataWritingAtomic error:&writeError];
  if (!success && error) {
    *error = writeError;
  }

  NSLog(@"[Config] Exported %lu configs to %@", (unsigned long)configDicts.count, url.path);
  return success;
}

- (BOOL)importConfigsFromURL:(NSURL *)url error:(NSError **)error {
  NSError *readError = nil;
  NSData *jsonData = [NSData dataWithContentsOfURL:url options:0 error:&readError];
  if (!jsonData) {
    if (error) {
      *error = readError ?: [NSError errorWithDomain:@"MSTConfigError"
                                                code:-2
                                            userInfo:@{NSLocalizedDescriptionKey : @"Failed to read config file"}];
    }
    return NO;
  }

  NSError *jsonError = nil;
  NSDictionary *importData = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:0
                                                               error:&jsonError];
  if (!importData || ![importData isKindOfClass:[NSDictionary class]]) {
    if (error) {
      *error = jsonError ?: [NSError errorWithDomain:@"MSTConfigError"
                                                code:-3
                                            userInfo:@{NSLocalizedDescriptionKey : @"Invalid JSON format"}];
    }
    return NO;
  }

  // Parse hosts
  NSArray *hostDicts = importData[@"hosts"];
  if (![hostDicts isKindOfClass:[NSArray class]]) {
    if (error) {
      *error = [NSError errorWithDomain:@"MSTConfigError"
                                   code:-4
                               userInfo:@{NSLocalizedDescriptionKey : @"Invalid config format: missing hosts array"}];
    }
    return NO;
  }

  // Clear existing configs and import new ones
  [self.mutableHostConfigs removeAllObjects];

  for (NSDictionary *dict in hostDicts) {
    if ([dict isKindOfClass:[NSDictionary class]]) {
      // Create new config with new identifier to avoid conflicts
      NSMutableDictionary *mutableDict = [dict mutableCopy];
      mutableDict[@"identifier"] = [[NSUUID UUID] UUIDString];
      mutableDict[@"isDefault"] = @NO;

      MSTS3HostConfig *config = [MSTS3HostConfig configFromDictionary:mutableDict];
      if (config) {
        [self.mutableHostConfigs addObject:config];
      }
    }
  }

  // Set default host
  if (self.mutableHostConfigs.count > 0) {
    self.mutableHostConfigs.firstObject.isDefault = YES;
    self.defaultHost = self.mutableHostConfigs.firstObject;
  } else {
    self.defaultHost = nil;
  }

  // Import settings if present
  NSDictionary *settings = importData[@"settings"];
  if ([settings isKindOfClass:[NSDictionary class]]) {
    if (settings[@"outputFormat"]) {
      self.outputFormat = [settings[@"outputFormat"] integerValue];
    }
    if (settings[@"compressFactor"]) {
      self.compressFactor = [settings[@"compressFactor"] integerValue];
    }
    if (settings[@"removeEXIF"]) {
      self.removeEXIF = [settings[@"removeEXIF"] boolValue];
    }
    if ([settings[@"shortLinkAPIKey"] isKindOfClass:[NSString class]]) {
      self.shortLinkAPIKey = settings[@"shortLinkAPIKey"];
    }
    if ([settings[@"shortLinkDefaultDomain"] isKindOfClass:[NSString class]] &&
        [settings[@"shortLinkDefaultDomain"] length] > 0) {
      self.shortLinkDefaultDomain = settings[@"shortLinkDefaultDomain"];
    }
    if ([settings[@"shortLinkDomains"] isKindOfClass:[NSArray class]]) {
      self.shortLinkDomains = settings[@"shortLinkDomains"];
    }
  }

  [self saveConfigs];

  NSLog(@"[Config] Imported %lu configs from %@", (unsigned long)self.mutableHostConfigs.count, url.path);

  [[NSNotificationCenter defaultCenter]
      postNotificationName:MSTConfigDidChangeNotification
                    object:nil];

  return YES;
}

@end
