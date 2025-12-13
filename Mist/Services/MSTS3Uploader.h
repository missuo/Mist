//
//  MSTS3Uploader.h
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import <Foundation/Foundation.h>

@class MSTS3HostConfig;

NS_ASSUME_NONNULL_BEGIN

typedef void (^MSTUploadProgressBlock)(double progress);
typedef void (^MSTUploadCompletionBlock)(NSString * _Nullable url, NSError * _Nullable error);

@interface MSTS3Uploader : NSObject

@property (nonatomic, strong, readonly, class) MSTS3Uploader *sharedUploader;
@property (nonatomic, assign, readonly) BOOL isUploading;

- (void)uploadFileAtURL:(NSURL *)fileURL
             withConfig:(MSTS3HostConfig *)config
               progress:(nullable MSTUploadProgressBlock)progressBlock
             completion:(MSTUploadCompletionBlock)completionBlock;

- (void)uploadData:(NSData *)data
          filename:(NSString *)filename
        withConfig:(MSTS3HostConfig *)config
          progress:(nullable MSTUploadProgressBlock)progressBlock
        completion:(MSTUploadCompletionBlock)completionBlock;

- (void)cancelUpload;

@end

NS_ASSUME_NONNULL_END
