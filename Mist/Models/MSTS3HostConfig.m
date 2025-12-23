//
//  MSTS3HostConfig.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTS3HostConfig.h"

static NSString *MSTSanitizeConfigString(NSString *value) {
  if (!value) {
    return @"";
  }
  NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSArray<NSString *> *components =
      [value componentsSeparatedByCharactersInSet:set];
  NSMutableArray<NSString *> *filtered = [NSMutableArray array];
  for (NSString *part in components) {
    if (part.length > 0) {
      [filtered addObject:part];
    }
  }
  return [filtered componentsJoinedByString:@""];
}

@implementation MSTS3HostConfig

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)init {
  return [self initWithIdentifier:[[NSUUID UUID] UUIDString]];
}

- (instancetype)initWithIdentifier:(NSString *)identifier {
  self = [super init];
  if (self) {
    _identifier = [identifier copy];
    _name = @"New S3 Host";
    _providerType = MSTS3ProviderTypeAmazonS3;
    _region = @"us-east-1";
    _endpoint = @"";
    _bucket = @"";
    _accessKey = @"";
    _secretKey = @"";
    _smmsToken = @"";
    _urlPrefix = @"";
    _saveKeyPath = @"{filename}.{ext}";
    _acl = @"public-read";
    _useHTTPS = YES;
    _shortLinkEnabled = NO;
    _isDefault = NO;
  }
  return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
  NSString *identifier = dict[@"identifier"] ?: [[NSUUID UUID] UUIDString];
  self = [self initWithIdentifier:identifier];
  if (self) {
    if (dict[@"name"])
      _name = dict[@"name"];
    if (dict[@"region"])
      _region = dict[@"region"];
    if (dict[@"endpoint"])
      _endpoint = MSTSanitizeConfigString(dict[@"endpoint"]);
    if (dict[@"bucket"])
      _bucket = dict[@"bucket"];
    if (dict[@"accessKey"])
      _accessKey = MSTSanitizeConfigString(dict[@"accessKey"]);
    if (dict[@"secretKey"])
      _secretKey = MSTSanitizeConfigString(dict[@"secretKey"]);
    if (dict[@"smmsToken"])
      _smmsToken = dict[@"smmsToken"];
    // Support both new urlPrefix and legacy domain key
    if (dict[@"urlPrefix"])
      _urlPrefix = MSTSanitizeConfigString(dict[@"urlPrefix"]);
    else if (dict[@"domain"])
      _urlPrefix = MSTSanitizeConfigString(dict[@"domain"]);
    if (dict[@"saveKeyPath"])
      _saveKeyPath = dict[@"saveKeyPath"];
    if (dict[@"acl"])
      _acl = dict[@"acl"];
    if (dict[@"useHTTPS"] != nil)
      _useHTTPS = [dict[@"useHTTPS"] boolValue];
    if (dict[@"shortLinkEnabled"])
      _shortLinkEnabled = [dict[@"shortLinkEnabled"] boolValue];
    if (dict[@"providerType"])
      _providerType = [dict[@"providerType"] integerValue];
    else if (dict[@"isCustomEndpoint"] && [dict[@"isCustomEndpoint"] boolValue])
      _providerType = MSTS3ProviderTypeCustom; // Migrate old configs
    if (dict[@"isDefault"])
      _isDefault = [dict[@"isDefault"] boolValue];
  }
  return self;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:_identifier forKey:@"identifier"];
  [coder encodeObject:_name forKey:@"name"];
  [coder encodeInteger:_providerType forKey:@"providerType"];
  [coder encodeObject:_region forKey:@"region"];
  [coder encodeObject:_endpoint forKey:@"endpoint"];
  [coder encodeObject:_bucket forKey:@"bucket"];
  [coder encodeObject:_accessKey forKey:@"accessKey"];
  [coder encodeObject:_secretKey forKey:@"secretKey"];
  [coder encodeObject:_smmsToken forKey:@"smmsToken"];
  [coder encodeObject:_urlPrefix forKey:@"urlPrefix"];
  [coder encodeObject:_saveKeyPath forKey:@"saveKeyPath"];
  [coder encodeObject:_acl forKey:@"acl"];
  [coder encodeBool:_useHTTPS forKey:@"useHTTPS"];
  [coder encodeBool:_shortLinkEnabled forKey:@"shortLinkEnabled"];
  [coder encodeBool:_isDefault forKey:@"isDefault"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  NSString *identifier = [coder decodeObjectOfClass:[NSString class]
                                             forKey:@"identifier"];
  self = [self initWithIdentifier:identifier ?: [[NSUUID UUID] UUIDString]];
  if (self) {
    _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"] ?: @"";
    _providerType = [coder decodeIntegerForKey:@"providerType"];
    // Migrate old configs that used isCustomEndpoint
    if (_providerType == 0 && [coder decodeBoolForKey:@"isCustomEndpoint"]) {
      _providerType = MSTS3ProviderTypeCustom;
    }
    _region = [coder decodeObjectOfClass:[NSString class] forKey:@"region"]
                  ?: @"us-east-1";
    _endpoint = MSTSanitizeConfigString([coder decodeObjectOfClass:[NSString class]
                                                             forKey:@"endpoint"] ?: @"");
    _bucket =
        [coder decodeObjectOfClass:[NSString class] forKey:@"bucket"] ?: @"";
    _accessKey = MSTSanitizeConfigString([coder decodeObjectOfClass:[NSString class]
                                                              forKey:@"accessKey"] ?: @"");
    _secretKey = MSTSanitizeConfigString([coder decodeObjectOfClass:[NSString class]
                                                              forKey:@"secretKey"] ?: @"");
    _smmsToken =
        [coder decodeObjectOfClass:[NSString class] forKey:@"smmsToken"] ?: @"";
    // Support both new urlPrefix and legacy domain key
    NSString *urlPrefixValue = [coder decodeObjectOfClass:[NSString class] forKey:@"urlPrefix"];
    if (!urlPrefixValue) {
      urlPrefixValue = [coder decodeObjectOfClass:[NSString class] forKey:@"domain"];
    }
    _urlPrefix = MSTSanitizeConfigString(urlPrefixValue ?: @"");
    _saveKeyPath = [coder decodeObjectOfClass:[NSString class]
                                       forKey:@"saveKeyPath"]
                       ?: @"";
    _acl = [coder decodeObjectOfClass:[NSString class] forKey:@"acl"]
               ?: @"public-read";
    // Default to YES for new configs and existing configs without this key
    _useHTTPS = [coder containsValueForKey:@"useHTTPS"] ? [coder decodeBoolForKey:@"useHTTPS"] : YES;
    _shortLinkEnabled = [coder decodeBoolForKey:@"shortLinkEnabled"];
    _isDefault = [coder decodeBoolForKey:@"isDefault"];
  }
  return self;
}

#pragma mark - Dictionary Conversion

- (NSDictionary *)toDictionary {
  return @{
    @"identifier" : self.identifier ?: @"",
    @"name" : self.name ?: @"",
    @"providerType" : @(self.providerType),
    @"region" : self.region ?: @"",
    @"endpoint" : self.endpoint ?: @"",
    @"bucket" : self.bucket ?: @"",
    @"accessKey" : self.accessKey ?: @"",
    @"secretKey" : self.secretKey ?: @"",
    @"smmsToken" : self.smmsToken ?: @"",
    @"urlPrefix" : self.urlPrefix ?: @"",
    @"saveKeyPath" : self.saveKeyPath ?: @"",
    @"acl" : self.acl ?: @"",
    @"useHTTPS" : @(self.useHTTPS),
    @"shortLinkEnabled" : @(self.shortLinkEnabled),
    @"isDefault" : @(self.isDefault)
  };
}

+ (nullable MSTS3HostConfig *)configFromDictionary:(NSDictionary *)dict {
  if (!dict)
    return nil;
  return [[MSTS3HostConfig alloc] initWithDictionary:dict];
}

#pragma mark - Computed Properties

- (BOOL)isCustomEndpoint {
  return self.providerType != MSTS3ProviderTypeAmazonS3;
}

- (instancetype)copyWithNewIdentifier {
  MSTS3HostConfig *copy = [[MSTS3HostConfig alloc] init];
  copy.name = [NSString stringWithFormat:@"%@ Copy", self.name];
  copy.providerType = self.providerType;
  copy.region = [self.region copy];
  copy.endpoint = [self.endpoint copy];
  copy.bucket = [self.bucket copy];
  copy.accessKey = [self.accessKey copy];
  copy.secretKey = [self.secretKey copy];
  copy.smmsToken = [self.smmsToken copy];
  copy.urlPrefix = [self.urlPrefix copy];
  copy.saveKeyPath = [self.saveKeyPath copy];
  copy.acl = [self.acl copy];
  copy.useHTTPS = self.useHTTPS;
  copy.shortLinkEnabled = self.shortLinkEnabled;
  copy.isDefault = NO;
  return copy;
}

#pragma mark - URL Computation

- (NSString *)baseURL {
  NSString *scheme = self.useHTTPS ? @"https" : @"http";

  // If URL prefix is set, use it as the base
  if (self.urlPrefix.length > 0) {
    NSString *prefix = self.urlPrefix;
    // Remove existing scheme if present
    if ([prefix hasPrefix:@"https://"]) {
      prefix = [prefix substringFromIndex:8];
    } else if ([prefix hasPrefix:@"http://"]) {
      prefix = [prefix substringFromIndex:7];
    }
    if ([prefix hasSuffix:@"/"]) {
      prefix = [prefix substringToIndex:prefix.length - 1];
    }
    return [NSString stringWithFormat:@"%@://%@", scheme, prefix];
  }

  // If URL prefix is empty, return empty string to indicate
  // that saveKeyPath contains the full domain+path
  // (e.g., saveKeyPath = "cdn.example.com/{filename}.{ext}")
  return @"";
}

- (NSString *)scheme {
  return self.useHTTPS ? @"https" : @"http";
}

- (NSString *)computedEndpoint {
  if (self.isCustomEndpoint && self.endpoint.length > 0) {
    NSString *e = self.endpoint;
    if (![e hasPrefix:@"http"]) {
      e = [NSString stringWithFormat:@"https://%@", e];
    }
    return e;
  }
  return
      [NSString stringWithFormat:@"https://s3.%@.amazonaws.com", self.region];
}

@end
