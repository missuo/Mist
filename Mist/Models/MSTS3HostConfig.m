//
//  MSTS3HostConfig.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTS3HostConfig.h"

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
    _domain = @"";
    _saveKeyPath = @"{filename}.{ext}";
    _acl = @"public-read";
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
      _endpoint = dict[@"endpoint"];
    if (dict[@"bucket"])
      _bucket = dict[@"bucket"];
    if (dict[@"accessKey"])
      _accessKey = dict[@"accessKey"];
    if (dict[@"secretKey"])
      _secretKey = dict[@"secretKey"];
    if (dict[@"domain"])
      _domain = dict[@"domain"];
    if (dict[@"saveKeyPath"])
      _saveKeyPath = dict[@"saveKeyPath"];
    if (dict[@"acl"])
      _acl = dict[@"acl"];
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
  [coder encodeObject:_domain forKey:@"domain"];
  [coder encodeObject:_saveKeyPath forKey:@"saveKeyPath"];
  [coder encodeObject:_acl forKey:@"acl"];
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
    _endpoint =
        [coder decodeObjectOfClass:[NSString class] forKey:@"endpoint"] ?: @"";
    _bucket =
        [coder decodeObjectOfClass:[NSString class] forKey:@"bucket"] ?: @"";
    _accessKey =
        [coder decodeObjectOfClass:[NSString class] forKey:@"accessKey"] ?: @"";
    _secretKey =
        [coder decodeObjectOfClass:[NSString class] forKey:@"secretKey"] ?: @"";
    _domain =
        [coder decodeObjectOfClass:[NSString class] forKey:@"domain"] ?: @"";
    _saveKeyPath = [coder decodeObjectOfClass:[NSString class]
                                       forKey:@"saveKeyPath"]
                       ?: @"";
    _acl = [coder decodeObjectOfClass:[NSString class] forKey:@"acl"]
               ?: @"public-read";
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
    @"domain" : self.domain ?: @"",
    @"saveKeyPath" : self.saveKeyPath ?: @"",
    @"acl" : self.acl ?: @"",
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
  copy.domain = [self.domain copy];
  copy.saveKeyPath = [self.saveKeyPath copy];
  copy.acl = [self.acl copy];
  copy.isDefault = NO;
  return copy;
}

#pragma mark - URL Computation

- (NSString *)baseURL {
  // If custom domain is set, use it
  if (self.domain.length > 0) {
    NSString *d = self.domain;
    if (![d hasPrefix:@"http"]) {
      d = [NSString stringWithFormat:@"https://%@", d];
    }
    if ([d hasSuffix:@"/"]) {
      d = [d substringToIndex:d.length - 1];
    }
    return d;
  }

  // If using custom endpoint
  if (self.isCustomEndpoint && self.endpoint.length > 0) {
    NSString *e = self.endpoint;
    if (![e hasPrefix:@"http"]) {
      e = [NSString stringWithFormat:@"https://%@", e];
    }
    if ([e hasSuffix:@"/"]) {
      e = [e substringToIndex:e.length - 1];
    }
    return [NSString stringWithFormat:@"%@/%@", e, self.bucket];
  }

  // AWS S3 URL format
  return [NSString stringWithFormat:@"https://%@.s3.%@.amazonaws.com",
                                    self.bucket, self.region];
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
