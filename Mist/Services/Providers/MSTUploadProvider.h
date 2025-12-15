//
//  MSTUploadProvider.h
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import <Foundation/Foundation.h>

@class MSTS3HostConfig;

NS_ASSUME_NONNULL_BEGIN

typedef void (^MSTProviderProgressBlock)(double progress);
typedef void (^MSTProviderCompletionBlock)(NSString *_Nullable url, NSError *_Nullable error);

@protocol MSTUploadProvider <NSObject>

@required
/// Validates the configuration for this provider
- (BOOL)validateConfig:(MSTS3HostConfig *)config error:(NSError *_Nullable *_Nullable)error;

/// Performs the upload and returns the result URL
- (void)uploadData:(NSData *)data
          filename:(NSString *)filename
        withConfig:(MSTS3HostConfig *)config
           session:(NSURLSession *)session
          progress:(nullable MSTProviderProgressBlock)progressBlock
        completion:(MSTProviderCompletionBlock)completion;

@optional
/// Returns the display name for this provider
+ (NSString *)providerName;

@end

NS_ASSUME_NONNULL_END
