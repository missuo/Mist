//
//  MSTConfigManager.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTConfigManager.h"
#import "MSTConstants.h"
#import "MSTS3HostConfig.h"

@interface MSTConfigManager ()

@property(nonatomic, strong)
    NSMutableArray<MSTS3HostConfig *> *mutableHostConfigs;
@property(nonatomic, strong) NSUserDefaults *userDefaults;

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

    _mutableHostConfigs = [NSMutableArray array];
    _outputFormat = MSTOutputFormatURL;
    _compressFactor = 100;
    [self loadConfigs];
  }
  return self;
}

#pragma mark - Properties

- (NSArray<MSTS3HostConfig *> *)hostConfigs {
  return [self.mutableHostConfigs copy];
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

  [self.userDefaults synchronize];
}

- (void)loadConfigs {
  // Load host configs
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
}

- (void)migrateFromStandardDefaultsIfNeeded {
  if (!self.userDefaults || self.userDefaults == [NSUserDefaults standardUserDefaults]) {
    return;
  }

  // If shared defaults already contain data, skip migration
  if ([self.userDefaults objectForKey:kMSTHostConfigs] ||
      [self.userDefaults objectForKey:kMSTDefaultHostId] ||
      [self.userDefaults objectForKey:kMSTOutputFormat] ||
      [self.userDefaults objectForKey:kMSTCompressFactor]) {
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

@end
