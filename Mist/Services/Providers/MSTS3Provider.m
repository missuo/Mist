//
//  MSTS3Provider.m
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import "MSTS3Provider.h"
#import "MSTS3HostConfig.h"
#import "MSTCryptoHelper.h"
#import "MSTUploadUtilities.h"

@implementation MSTS3Provider

+ (NSString *)providerName {
  return @"S3";
}

#pragma mark - MSTUploadProvider

- (BOOL)validateConfig:(MSTS3HostConfig *)config error:(NSError **)error {
  if (config.bucket.length == 0 || config.accessKey.length == 0 ||
      config.secretKey.length == 0) {
    if (error) {
      *error = [NSError
          errorWithDomain:@"MSTUploaderError"
                     code:-3
                 userInfo:@{NSLocalizedDescriptionKey : @"Invalid S3 configuration"}];
    }
    return NO;
  }
  return YES;
}

- (void)uploadData:(NSData *)data
          filename:(NSString *)filename
        withConfig:(MSTS3HostConfig *)config
           session:(NSURLSession *)session
          progress:(MSTProviderProgressBlock)progressBlock
        completion:(MSTProviderCompletionBlock)completion {

  // Generate save key from path template
  NSString *saveKey = [MSTUploadUtilities generateSaveKeyWithTemplate:config.saveKeyPath
                                                             filename:filename];
  NSString *encodedSaveKey = [MSTUploadUtilities uriEncode:saveKey encodeSlash:NO];

  NSLog(@"[Mist] S3 upload request starting: %@/%@", config.baseURL, saveKey);

  // Get content type
  NSString *contentType = [MSTUploadUtilities mimeTypeForFilename:filename];

  // Build the request
  NSMutableURLRequest *request = [self buildS3RequestWithConfig:config
                                                           data:data
                                                 encodedSaveKey:encodedSaveKey
                                                    contentType:contentType];

  if (!request) {
    NSError *error = [NSError
        errorWithDomain:@"MSTUploaderError"
                   code:-2
               userInfo:@{NSLocalizedDescriptionKey : @"Failed to build S3 request"}];
    completion(nil, error);
    return;
  }

  NSURLSessionDataTask *task = [session
      dataTaskWithRequest:request
        completionHandler:^(NSData *_Nullable responseData,
                            NSURLResponse *_Nullable response,
                            NSError *_Nullable error) {
          NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

          if (error) {
            NSLog(@"[Mist] S3 upload network error: %@", error);
            completion(nil, error);
            return;
          }

          if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
            NSString *baseURL = config.baseURL;
            NSLog(@"[Mist] S3 upload success - URLPrefix: '%@', BaseURL: '%@'",
                  config.urlPrefix, baseURL);
            NSString *url;
            if (baseURL.length > 0) {
              url = [NSString stringWithFormat:@"%@/%@", baseURL, encodedSaveKey];
            } else {
              NSRange separator = [saveKey rangeOfString:@"/"];
              NSString *host = saveKey;
              NSString *path = @"";
              if (separator.location != NSNotFound) {
                host = [saveKey substringToIndex:separator.location];
                path = [encodedSaveKey substringFromIndex:
                    [encodedSaveKey rangeOfString:@"/"].location];
              }
              url = [NSString stringWithFormat:@"%@://%@%@", config.scheme, host, path];
            }
            completion(url, nil);
          } else {
            NSString *responseBody = [[NSString alloc] initWithData:responseData
                                                            encoding:NSUTF8StringEncoding];
            NSString *bodyForLog = responseBody.length > 0 ? responseBody : @"<empty body>";
            NSDictionary *headers = httpResponse.allHeaderFields ?: @{};

            NSLog(@"[Mist] S3 upload failed. Status: %ld, URL: %@, Headers: %@, Body: %@",
                  (long)httpResponse.statusCode, httpResponse.URL.absoluteString, headers, bodyForLog);

            NSString *errorDescription = responseBody.length > 0 ? responseBody : @"Upload failed";
            NSError *uploadError =
                [NSError errorWithDomain:@"MSTUploaderError"
                                    code:httpResponse.statusCode
                                userInfo:@{
                                  NSLocalizedDescriptionKey : errorDescription,
                                  @"statusCode" : @(httpResponse.statusCode),
                                  @"responseBody" : bodyForLog
                                }];
            completion(nil, uploadError);
          }
        }];

  [task resume];
}

#pragma mark - AWS Signature V4

- (NSMutableURLRequest *)buildS3RequestWithConfig:(MSTS3HostConfig *)config
                                             data:(NSData *)data
                                   encodedSaveKey:(NSString *)encodedSaveKey
                                      contentType:(NSString *)contentType {

  // Build URL
  NSString *host;
  NSString *canonicalURI;
  NSString *urlString;
  NSString *region;

  if (config.isCustomEndpoint) {
    // Custom S3-compatible endpoint (e.g., R2, Wasabi, MinIO)
    NSString *endpoint = config.endpoint;
    if (![endpoint hasPrefix:@"http"]) {
      endpoint = [NSString stringWithFormat:@"https://%@", endpoint];
    }
    if ([endpoint hasSuffix:@"/"]) {
      endpoint = [endpoint substringToIndex:endpoint.length - 1];
    }

    // Extract host from endpoint
    NSURL *endpointURL = [NSURL URLWithString:endpoint];
    host = endpointURL.host;

    // Path-style: /bucket/key
    canonicalURI =
        [NSString stringWithFormat:@"/%@/%@", config.bucket, encodedSaveKey];
    urlString = [NSString stringWithFormat:@"%@%@", endpoint, canonicalURI];

    // Determine region based on provider
    if (config.providerType == MSTS3ProviderTypeBackblazeB2) {
      // B2: Extract region from endpoint (e.g., s3.us-west-004.backblazeb2.com)
      region = [MSTUploadUtilities extractRegionFromB2Endpoint:host] ?: @"us-west-004";
    } else {
      // Use the config's region (Wasabi, R2=auto, Custom=us-east-1, etc)
      region = config.region ?: @"us-east-1";
    }
  } else {
    // AWS S3 virtual-hosted style
    host = [NSString stringWithFormat:@"%@.s3.%@.amazonaws.com", config.bucket,
                                      config.region];
    canonicalURI = [NSString stringWithFormat:@"/%@", encodedSaveKey];
    urlString = [NSString stringWithFormat:@"https://%@%@", host, canonicalURI];
    region = config.region;
  }

  NSURL *url = [NSURL URLWithString:urlString];
  if (!url) {
    NSLog(@"[Mist] Failed to create URL from: %@", urlString);
    return nil;
  }

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  request.HTTPMethod = @"PUT";
  request.HTTPBody = data;

  // Date formatting - use a single date for consistency
  NSDate *now = [NSDate date];
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  dateFormatter.locale =
      [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
  dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
  dateFormatter.dateFormat = @"yyyyMMdd'T'HHmmss'Z'";
  NSString *amzDate = [dateFormatter stringFromDate:now];

  dateFormatter.dateFormat = @"yyyyMMdd";
  NSString *dateStamp = [dateFormatter stringFromDate:now];

  // Content hash
  NSString *payloadHash = [MSTCryptoHelper sha256HashHex:data];

  // Build headers dictionary for signing
  NSMutableDictionary *headers = [NSMutableDictionary dictionary];
  headers[@"host"] = host;
  headers[@"x-amz-date"] = amzDate;
  headers[@"x-amz-content-sha256"] = payloadHash;
  headers[@"content-type"] = contentType;

  if (config.acl.length > 0 && ![config.acl isEqualToString:@"private"]) {
    headers[@"x-amz-acl"] = config.acl;
  }

  // Set headers on request
  for (NSString *key in headers) {
    [request setValue:headers[key] forHTTPHeaderField:key];
  }
  [request setValue:[@(data.length) stringValue]
      forHTTPHeaderField:@"Content-Length"];

  // Build canonical request
  NSString *service = @"s3";

  // Sort headers alphabetically
  NSArray *sortedKeys =
      [[headers allKeys] sortedArrayUsingSelector:@selector(compare:)];

  NSMutableString *canonicalHeaders = [NSMutableString string];
  for (NSString *key in sortedKeys) {
    [canonicalHeaders
        appendFormat:@"%@:%@\n", key.lowercaseString, headers[key]];
  }

  NSString *signedHeaders = [[sortedKeys valueForKey:@"lowercaseString"]
      componentsJoinedByString:@";"];

  // Canonical request format:
  // HTTPMethod + '\n' +
  // CanonicalURI + '\n' +
  // CanonicalQueryString + '\n' +
  // CanonicalHeaders + '\n' +
  // SignedHeaders + '\n' +
  // HashedPayload
  NSString *canonicalRequest =
      [NSString stringWithFormat:@"PUT\n%@\n\n%@\n%@\n%@", canonicalURI,
                                 canonicalHeaders, signedHeaders, payloadHash];

  // String to sign
  NSString *algorithm = @"AWS4-HMAC-SHA256";
  NSString *credentialScope = [NSString
      stringWithFormat:@"%@/%@/%@/aws4_request", dateStamp, region, service];
  NSString *hashedCanonicalRequest =
      [MSTCryptoHelper sha256HashHexString:canonicalRequest];
  NSString *stringToSign =
      [NSString stringWithFormat:@"%@\n%@\n%@\n%@", algorithm, amzDate,
                                 credentialScope, hashedCanonicalRequest];

  // Calculate signature
  NSData *kDate =
      [MSTCryptoHelper hmacSHA256:dateStamp
                          withKey:[@"AWS4" stringByAppendingString:config.secretKey]];
  NSData *kRegion = [MSTCryptoHelper hmacSHA256Data:region withKeyData:kDate];
  NSData *kService = [MSTCryptoHelper hmacSHA256Data:service withKeyData:kRegion];
  NSData *kSigning = [MSTCryptoHelper hmacSHA256Data:@"aws4_request" withKeyData:kService];
  NSString *signature = [MSTCryptoHelper hmacSHA256HexData:stringToSign
                                              withKeyData:kSigning];

  // Build authorization header
  NSString *authorization = [NSString
      stringWithFormat:@"%@ Credential=%@/%@, SignedHeaders=%@, Signature=%@",
                       algorithm, config.accessKey, credentialScope,
                       signedHeaders, signature];

  [request setValue:authorization forHTTPHeaderField:@"Authorization"];

  // Debug logging for S3-compatible endpoints (e.g., Backblaze B2) to verify
  // SigV4 inputs without exposing secrets.
  if (config.providerType == MSTS3ProviderTypeBackblazeB2 || config.isCustomEndpoint) {
    NSString *payloadHashPreview = payloadHash.length >= 16 ? [payloadHash substringToIndex:16]
                                                            : payloadHash;
    NSString *canonicalHashPreview = hashedCanonicalRequest.length >= 16
                                         ? [hashedCanonicalRequest substringToIndex:16]
                                         : hashedCanonicalRequest;

    NSLog(@"[Mist] SigV4 debug — host: %@, region: %@, url: %@, canonicalURI: %@, signedHeaders: %@, payloadHash(prefix): %@, canonicalHash(prefix): %@, credentialScope: %@",
          host, region, urlString, canonicalURI, signedHeaders, payloadHashPreview,
          canonicalHashPreview, credentialScope);
  }

  return request;
}

@end
