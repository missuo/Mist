//
//  MSTS3Uploader.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTS3Uploader.h"
#import "MSTConstants.h"
#import "MSTS3HostConfig.h"
#import "MSTImageProcessor.h"
#import "MSTProviderFactory.h"
#import "MSTUploadProvider.h"

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
@property(nonatomic, strong, nullable) NSURLSessionTask *currentTask;
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
  data = [MSTImageProcessor processImageDataIfNeeded:data filename:filename];

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

  // Validate config using provider
  id<MSTUploadProvider> provider = [MSTProviderFactory providerForConfig:config];
  NSError *validationError = nil;
  if (![provider validateConfig:config error:&validationError]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      completionBlock(nil, validationError);
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

  // Get the appropriate provider
  id<MSTUploadProvider> provider = [MSTProviderFactory providerForConfig:item.config];

  // Perform upload using provider
  [provider uploadData:item.data
              filename:item.filename
            withConfig:item.config
               session:self.session
              progress:item.progressBlock
            completion:^(NSString *url, NSError *error) {
              self.isUploading = NO;
              self.currentTask = nil;
              self.progressBlock = nil;

              if (error) {
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:MSTUploadDidFailNotification
                                  object:nil
                                userInfo:@{@"error" : error}];
                dispatch_async(dispatch_get_main_queue(), ^{
                  item.completionBlock(nil, error);
                });
              } else {
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:MSTUploadDidFinishNotification
                                  object:nil
                                userInfo:@{
                                  @"url" : url,
                                  @"filename" : item.filename ?: @"",
                                  @"fileSize" : @(item.data.length),
                                  @"config" : item.config,
                                  @"data" : item.data ?: [NSData data]
                                }];
                dispatch_async(dispatch_get_main_queue(), ^{
                  item.completionBlock(url, nil);
                });
              }

              // Process next upload
              [self processNextUpload];
            }];
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

@end
