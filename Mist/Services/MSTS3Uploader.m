//
//  MSTS3Uploader.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTS3Uploader.h"
#import "MSTConstants.h"
#import "MSTS3HostConfig.h"
#import "MSTS3Region.h"
#import "MSTConfigManager.h"
#import <AppKit/AppKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MSTUploadQueueItem : NSObject
@property(nonatomic, strong) NSData *data;
@property(nonatomic, copy) NSString *filename;
@property(nonatomic, strong) MSTS3HostConfig *config;
@property(nonatomic, copy, nullable) MSTUploadProgressBlock progressBlock;
@property(nonatomic, copy) MSTUploadCompletionBlock completionBlock;
@end

@implementation MSTUploadQueueItem
@end

@interface MSTS3Uploader () <NSURLSessionTaskDelegate>

@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong, nullable) NSURLSessionDataTask *currentTask;
@property(nonatomic, assign) BOOL isUploading;
@property(nonatomic, copy, nullable) MSTUploadProgressBlock progressBlock;
@property(nonatomic, strong) NSMutableArray<MSTUploadQueueItem *> *uploadQueue;
@property(nonatomic, strong) dispatch_queue_t queueProcessingQueue;

@end

@implementation MSTS3Uploader

+ (MSTS3Uploader *)sharedUploader {
  static MSTS3Uploader *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[MSTS3Uploader alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 60.0;
    config.timeoutIntervalForResource = 300.0;
    _session = [NSURLSession sessionWithConfiguration:config
                                             delegate:self
                                        delegateQueue:nil];
    _uploadQueue = [NSMutableArray array];
    _queueProcessingQueue = dispatch_queue_create("nz.owo.Mist.uploadQueue", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

#pragma mark - Public Methods

- (void)uploadFileAtURL:(NSURL *)fileURL
             withConfig:(MSTS3HostConfig *)config
               progress:(nullable MSTUploadProgressBlock)progressBlock
             completion:(MSTUploadCompletionBlock)completionBlock {
  NSLog(@"[Mist] Preparing upload for %@", fileURL.path);
  
  // Check if file exists first
  BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fileURL.path];
  NSLog(@"[Mist] File exists: %@", fileExists ? @"YES" : @"NO");
  if (!fileExists) {
    NSError *error = [NSError
        errorWithDomain:@"MSTUploaderError"
                   code:-1
               userInfo:@{
                 NSLocalizedDescriptionKey :
                     [NSString stringWithFormat:@"File not found: %@", fileURL.path]
               }];
    
    NSLog(@"[Mist] File read failed: %@", error.localizedDescription);
    
    [[NSNotificationCenter defaultCenter]
        postNotificationName:MSTUploadDidFailNotification
                      object:nil
                    userInfo:@{@"error" : error}];
    
    dispatch_async(dispatch_get_main_queue(), ^{
      completionBlock(nil, error);
    });
    return;
  }

  BOOL didStartSecurityScope = [fileURL startAccessingSecurityScopedResource];
  NSLog(@"[Mist] Security scoped resource access: %@", didStartSecurityScope ? @"YES" : @"NO");
  
  NSError *readError = nil;
  NSData *data = [NSData dataWithContentsOfURL:fileURL
                                        options:NSDataReadingMappedIfSafe
                                          error:&readError];
  if (didStartSecurityScope) {
    [fileURL stopAccessingSecurityScopedResource];
  }
  if (!data) {
    NSError *error = readError;

    if (error && error.domain == NSCocoaErrorDomain &&
        error.code == NSFileReadNoPermissionError) {
      error = [NSError
          errorWithDomain:@"MSTUploaderError"
                     code:-1
                 userInfo:@{
                   NSLocalizedDescriptionKey :
                       @"Cannot read file due to permissions. Please grant Full Disk Access in System Settings."
                 }];
    } else if (!error) {
      error = [NSError
          errorWithDomain:@"MSTUploaderError"
                     code:-1
                 userInfo:@{
                   NSLocalizedDescriptionKey :
                       @"Failed to read file. Please grant Full Disk Access if the file is protected."
                 }];
    }
    
    NSLog(@"[Mist] File read failed: %@", error.localizedDescription);
    
    [[NSNotificationCenter defaultCenter]
        postNotificationName:MSTUploadDidFailNotification
                      object:nil
                    userInfo:@{@"error" : error}];
    
    dispatch_async(dispatch_get_main_queue(), ^{
      completionBlock(nil, error);
    });
    return;
  }

  NSString *filename = fileURL.lastPathComponent;
  NSLog(@"[Mist] Read file succeeded (%lu bytes). Starting upload...",
        (unsigned long)data.length);
  
  // Process image if needed (compression and/or EXIF removal)
  data = [self processImageDataIfNeeded:data filename:filename];
  
  [self uploadData:data
          filename:filename
        withConfig:config
          progress:progressBlock
        completion:completionBlock];
}

- (void)uploadData:(NSData *)data
          filename:(NSString *)filename
        withConfig:(MSTS3HostConfig *)config
          progress:(nullable MSTUploadProgressBlock)progressBlock
        completion:(MSTUploadCompletionBlock)completionBlock {

  // Validate config
  if (config.bucket.length == 0 || config.accessKey.length == 0 ||
      config.secretKey.length == 0) {
    NSError *error = [NSError
        errorWithDomain:@"MSTUploaderError"
                   code:-3
               userInfo:@{
                 NSLocalizedDescriptionKey : @"Invalid S3 configuration"
               }];
    dispatch_async(dispatch_get_main_queue(), ^{
      completionBlock(nil, error);
    });
    return;
  }

  // Create queue item
  MSTUploadQueueItem *item = [[MSTUploadQueueItem alloc] init];
  item.data = data;
  item.filename = filename;
  item.config = config;
  item.progressBlock = progressBlock;
  item.completionBlock = completionBlock;
  
  dispatch_async(self.queueProcessingQueue, ^{
    [self.uploadQueue addObject:item];
    NSLog(@"[Mist] Added to queue. Queue size: %lu", (unsigned long)self.uploadQueue.count);
    [self processNextUpload];
  });
}

- (void)processNextUpload {
  dispatch_async(self.queueProcessingQueue, ^{
    if (self.isUploading || self.uploadQueue.count == 0) {
      return;
    }
    
    MSTUploadQueueItem *item = self.uploadQueue.firstObject;
    [self.uploadQueue removeObjectAtIndex:0];
    
    NSLog(@"[Mist] Processing upload. Remaining in queue: %lu", (unsigned long)self.uploadQueue.count);
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [self performUploadWithItem:item];
    });
  });
}

- (void)performUploadWithItem:(MSTUploadQueueItem *)item {
  self.isUploading = YES;
  self.progressBlock = item.progressBlock;

  [[NSNotificationCenter defaultCenter]
      postNotificationName:MSTUploadDidStartNotification
                    object:nil];

  // Generate save key from path template
  NSString *saveKey = [self generateSaveKeyWithTemplate:item.config.saveKeyPath
                                               filename:item.filename];
  
  NSLog(@"[Mist] Upload request starting: %@/%@", item.config.baseURL, saveKey);

  // Get content type
  NSString *contentType = [self mimeTypeForFilename:item.filename];

  // Build the request
  NSMutableURLRequest *request = [self buildS3RequestWithConfig:item.config
                                                           data:item.data
                                                        saveKey:saveKey
                                                    contentType:contentType];

  NSURLSessionDataTask *task = [self.session
      dataTaskWithRequest:request
        completionHandler:^(NSData *_Nullable responseData,
                            NSURLResponse *_Nullable response,
                            NSError *_Nullable error) {
          self.isUploading = NO;
          self.currentTask = nil;
          self.progressBlock = nil;

          NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

          if (error) {
            [[NSNotificationCenter defaultCenter]
                postNotificationName:MSTUploadDidFailNotification
                              object:nil
                            userInfo:@{@"error" : error}];
            dispatch_async(dispatch_get_main_queue(), ^{
              item.completionBlock(nil, error);
            });
            
            // Process next upload
            [self processNextUpload];
            return;
          }

          if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
            NSLog(@"Upload success - Domain: '%@', BaseURL: '%@'",
                  item.config.domain, item.config.baseURL);
            NSString *url =
                [NSString stringWithFormat:@"%@/%@", item.config.baseURL, saveKey];

            [[NSNotificationCenter defaultCenter]
                postNotificationName:MSTUploadDidFinishNotification
                              object:nil
                            userInfo:@{@"url" : url}];
            dispatch_async(dispatch_get_main_queue(), ^{
              item.completionBlock(url, nil);
            });
            
            // Process next upload
            [self processNextUpload];
          } else {
            NSString *errorMessage =
                [[NSString alloc] initWithData:responseData
                                      encoding:NSUTF8StringEncoding];
            NSLog(@"S3 Upload Error [%ld]: %@", (long)httpResponse.statusCode,
                  errorMessage);
            NSError *uploadError =
                [NSError errorWithDomain:@"MSTUploaderError"
                                    code:httpResponse.statusCode
                                userInfo:@{
                                  NSLocalizedDescriptionKey : errorMessage
                                      ?: @"Upload failed"
                                }];
            [[NSNotificationCenter defaultCenter]
                postNotificationName:MSTUploadDidFailNotification
                              object:nil
                            userInfo:@{@"error" : uploadError}];
            dispatch_async(dispatch_get_main_queue(), ^{
              item.completionBlock(nil, uploadError);
            });
            
            // Process next upload
            [self processNextUpload];
          }
        }];

  self.currentTask = task;
  [task resume];
}

- (void)cancelUpload {
  [self.currentTask cancel];
  self.currentTask = nil;
  self.isUploading = NO;
  self.progressBlock = nil;
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
                        task:(NSURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {

  if (self.progressBlock && totalBytesExpectedToSend > 0) {
    double progress = (double)totalBytesSent / (double)totalBytesExpectedToSend;
    dispatch_async(dispatch_get_main_queue(), ^{
      self.progressBlock(progress);
      [[NSNotificationCenter defaultCenter]
          postNotificationName:MSTUploadProgressNotification
                        object:nil
                      userInfo:@{
                        @"progress" : @(progress)
                      }];
    });
  }
}

#pragma mark - AWS Signature V4

- (NSMutableURLRequest *)buildS3RequestWithConfig:(MSTS3HostConfig *)config
                                             data:(NSData *)data
                                          saveKey:(NSString *)saveKey
                                      contentType:(NSString *)contentType {

  // URI encode the save key for path (but not for signing)
  NSString *encodedSaveKey = [self uriEncode:saveKey encodeSlash:NO];

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
      region = [self extractRegionFromB2Endpoint:host] ?: @"us-west-004";
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
    NSLog(@"Failed to create URL from: %@", urlString);
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
  NSString *payloadHash = [self sha256HashHex:data];

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
      [self sha256HashHexString:canonicalRequest];
  NSString *stringToSign =
      [NSString stringWithFormat:@"%@\n%@\n%@\n%@", algorithm, amzDate,
                                 credentialScope, hashedCanonicalRequest];

  // Calculate signature
  NSData *kDate =
      [self hmacSHA256:dateStamp
               withKey:[@"AWS4" stringByAppendingString:config.secretKey]];
  NSData *kRegion = [self hmacSHA256Data:region withKeyData:kDate];
  NSData *kService = [self hmacSHA256Data:service withKeyData:kRegion];
  NSData *kSigning = [self hmacSHA256Data:@"aws4_request" withKeyData:kService];
  NSString *signature = [self hmacSHA256HexData:stringToSign
                                    withKeyData:kSigning];

  // Build authorization header
  NSString *authorization = [NSString
      stringWithFormat:@"%@ Credential=%@/%@, SignedHeaders=%@, Signature=%@",
                       algorithm, config.accessKey, credentialScope,
                       signedHeaders, signature];

  [request setValue:authorization forHTTPHeaderField:@"Authorization"];

  return request;
}

#pragma mark - Image Processing

- (BOOL)isImageFile:(NSString *)filename {
  NSString *ext = [[filename pathExtension] lowercaseString];
  NSSet *imageExtensions = [NSSet setWithArray:@[
    @"jpg", @"jpeg", @"png", @"gif", @"bmp", @"tiff", @"tif",
    @"heic", @"heif", @"webp", @"ico"
  ]];
  return [imageExtensions containsObject:ext];
}

- (NSData *)processImageDataIfNeeded:(NSData *)data filename:(NSString *)filename {
  if (![self isImageFile:filename]) {
    return data;
  }
  
  MSTConfigManager *config = [MSTConfigManager sharedManager];
  BOOL shouldCompress = config.compressFactor > 0;
  BOOL shouldRemoveEXIF = config.removeEXIF;
  
  if (!shouldCompress && !shouldRemoveEXIF) {
    return data;
  }
  
  NSImage *image = [[NSImage alloc] initWithData:data];
  if (!image || image.representations.count == 0) {
    NSLog(@"[Mist] Failed to load image, skipping processing");
    return data;
  }
  
  // Get the first representation
  NSImageRep *imageRep = image.representations.firstObject;
  NSBitmapImageRep *bitmapRep = nil;
  
  if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
    bitmapRep = (NSBitmapImageRep *)imageRep;
  } else {
    // Convert to bitmap representation
    NSSize imageSize = image.size;
    bitmapRep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:imageSize.width
                      pixelsHigh:imageSize.height
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                     bytesPerRow:0
                    bitsPerPixel:0];
    
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmapRep];
    [NSGraphicsContext setCurrentContext:context];
    [image drawInRect:NSMakeRect(0, 0, imageSize.width, imageSize.height)];
    [NSGraphicsContext restoreGraphicsState];
  }
  
  // Determine output format based on file extension
  NSString *ext = [[filename pathExtension] lowercaseString];
  NSBitmapImageFileType fileType = NSBitmapImageFileTypePNG;
  
  if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) {
    fileType = NSBitmapImageFileTypeJPEG;
  } else if ([ext isEqualToString:@"png"]) {
    fileType = NSBitmapImageFileTypePNG;
  } else if ([ext isEqualToString:@"gif"]) {
    fileType = NSBitmapImageFileTypeGIF;
  } else if ([ext isEqualToString:@"bmp"]) {
    fileType = NSBitmapImageFileTypeBMP;
  } else if ([ext isEqualToString:@"tiff"] || [ext isEqualToString:@"tif"]) {
    fileType = NSBitmapImageFileTypeTIFF;
  } else {
    // Default to PNG for unknown formats
    fileType = NSBitmapImageFileTypePNG;
  }
  
  // Build properties dictionary
  NSMutableDictionary *properties = [NSMutableDictionary dictionary];
  
  // Apply compression if enabled
  if (shouldCompress && config.compressFactor >= 10 && config.compressFactor <= 90) {
    CGFloat compressionFactor = config.compressFactor / 100.0;
    properties[NSImageCompressionFactor] = @(compressionFactor);
    NSLog(@"[Mist] Compressing image with quality: %ld%%", (long)config.compressFactor);
  }
  
  // Remove EXIF if requested
  if (shouldRemoveEXIF) {
    // By not including existing properties, EXIF data will be stripped
    properties[NSImageEXIFData] = [NSData data]; // Empty EXIF
    NSLog(@"[Mist] Removing EXIF data from image");
  }
  
  NSData *processedData = [bitmapRep representationUsingType:fileType
                                                  properties:properties];
  
  if (processedData) {
    NSLog(@"[Mist] Image processing complete. Original: %lu bytes, Processed: %lu bytes",
          (unsigned long)data.length, (unsigned long)processedData.length);
    return processedData;
  } else {
    NSLog(@"[Mist] Image processing failed, using original data");
    return data;
  }
}

#pragma mark - Helpers

- (NSString *)uriEncode:(NSString *)string encodeSlash:(BOOL)encodeSlash {
  NSMutableCharacterSet *allowed =
      [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
  [allowed addCharactersInString:@"-._~"];
  if (!encodeSlash) {
    [allowed addCharactersInString:@"/"];
  }
  return [string stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

- (nullable NSString *)extractRegionFromB2Endpoint:(NSString *)host {
  // B2 endpoint format: s3.{region}.backblazeb2.com
  // Example: s3.us-west-004.backblazeb2.com -> us-west-004
  if (!host || host.length == 0) {
    return nil;
  }

  NSArray *components = [host componentsSeparatedByString:@"."];
  // Expected: ["s3", "us-west-004", "backblazeb2", "com"]
  if (components.count >= 4 && [components[0] isEqualToString:@"s3"] &&
      [components[components.count - 2] isEqualToString:@"backblazeb2"]) {
    return components[1];
  }

  return nil;
}

- (NSString *)generateSaveKeyWithTemplate:(NSString *)template
                                 filename:(NSString *)filename {
  NSDate *now = [NSDate date];
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *components =
      [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth |
                            NSCalendarUnitDay | NSCalendarUnitHour |
                            NSCalendarUnitMinute | NSCalendarUnitSecond)
                  fromDate:now];

  NSString *name = [filename stringByDeletingPathExtension];
  NSString *ext = [filename pathExtension];
  NSString *timestamp =
      [NSString stringWithFormat:@"%ld", (long)[now timeIntervalSince1970]];
  NSString *uuid = [[[NSUUID UUID] UUIDString] lowercaseString];
  NSString *random = [uuid substringToIndex:8];

  NSString *result = template;
  result = [result
      stringByReplacingOccurrencesOfString:@"{year}"
                                withString:[NSString
                                               stringWithFormat:@"%04ld",
                                                                (long)components
                                                                    .year]];
  result = [result
      stringByReplacingOccurrencesOfString:@"{month}"
                                withString:[NSString
                                               stringWithFormat:@"%02ld",
                                                                (long)components
                                                                    .month]];
  result = [result
      stringByReplacingOccurrencesOfString:@"{day}"
                                withString:[NSString
                                               stringWithFormat:@"%02ld",
                                                                (long)components
                                                                    .day]];
  result = [result
      stringByReplacingOccurrencesOfString:@"{hour}"
                                withString:[NSString
                                               stringWithFormat:@"%02ld",
                                                                (long)components
                                                                    .hour]];
  result = [result
      stringByReplacingOccurrencesOfString:@"{minute}"
                                withString:[NSString
                                               stringWithFormat:@"%02ld",
                                                                (long)components
                                                                    .minute]];
  result = [result
      stringByReplacingOccurrencesOfString:@"{second}"
                                withString:[NSString
                                               stringWithFormat:@"%02ld",
                                                                (long)components
                                                                    .second]];
  result = [result stringByReplacingOccurrencesOfString:@"{timestamp}"
                                             withString:timestamp];
  result = [result stringByReplacingOccurrencesOfString:@"{filename}"
                                             withString:name];
  result = [result stringByReplacingOccurrencesOfString:@"{ext}"
                                             withString:ext];
  result = [result stringByReplacingOccurrencesOfString:@"{random}"
                                             withString:random];
  result = [result stringByReplacingOccurrencesOfString:@"{uuid}"
                                             withString:uuid];

  return result;
}

- (NSString *)mimeTypeForFilename:(NSString *)filename {
  NSString *ext = [filename pathExtension].lowercaseString;

  if (@available(macOS 11.0, *)) {
    UTType *type = [UTType typeWithFilenameExtension:ext];
    if (type.preferredMIMEType) {
      return type.preferredMIMEType;
    }
  }

  // Fallback for common image types
  NSDictionary *mimeTypes = @{
    @"png" : @"image/png",
    @"jpg" : @"image/jpeg",
    @"jpeg" : @"image/jpeg",
    @"gif" : @"image/gif",
    @"bmp" : @"image/bmp",
    @"webp" : @"image/webp",
    @"svg" : @"image/svg+xml",
    @"ico" : @"image/x-icon",
    @"tiff" : @"image/tiff",
    @"tif" : @"image/tiff",
    @"heic" : @"image/heic",
    @"heif" : @"image/heif",
    @"pdf" : @"application/pdf",
    @"mp4" : @"video/mp4",
    @"mov" : @"video/quicktime",
    @"avi" : @"video/x-msvideo",
    @"zip" : @"application/zip",
    @"json" : @"application/json",
    @"xml" : @"application/xml",
    @"txt" : @"text/plain",
    @"html" : @"text/html",
    @"css" : @"text/css",
    @"js" : @"application/javascript"
  };

  return mimeTypes[ext] ?: @"application/octet-stream";
}

#pragma mark - Crypto Helpers

- (NSString *)sha256HashHex:(NSData *)data {
  unsigned char hash[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, hash);

  NSMutableString *result =
      [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [result appendFormat:@"%02x", hash[i]];
  }
  return result;
}

- (NSString *)sha256HashHexString:(NSString *)string {
  return [self sha256HashHex:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSData *)hmacSHA256:(NSString *)data withKey:(NSString *)key {
  const char *cKey = [key cStringUsingEncoding:NSUTF8StringEncoding];
  const char *cData = [data cStringUsingEncoding:NSUTF8StringEncoding];
  unsigned char result[CC_SHA256_DIGEST_LENGTH];

  CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), result);

  return [NSData dataWithBytes:result length:CC_SHA256_DIGEST_LENGTH];
}

- (NSData *)hmacSHA256Data:(NSString *)data withKeyData:(NSData *)keyData {
  const char *cData = [data cStringUsingEncoding:NSUTF8StringEncoding];
  unsigned char result[CC_SHA256_DIGEST_LENGTH];

  CCHmac(kCCHmacAlgSHA256, keyData.bytes, keyData.length, cData, strlen(cData),
         result);

  return [NSData dataWithBytes:result length:CC_SHA256_DIGEST_LENGTH];
}

- (NSString *)hmacSHA256HexData:(NSString *)data withKeyData:(NSData *)keyData {
  NSData *hmacData = [self hmacSHA256Data:data withKeyData:keyData];

  NSMutableString *result =
      [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  const unsigned char *bytes = hmacData.bytes;
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [result appendFormat:@"%02x", bytes[i]];
  }
  return result;
}

@end
