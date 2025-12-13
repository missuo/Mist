//
//  MSTUploadHelper.h
//  Mist
//
//  Created by Factory Droid.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const MSTUploadHelperErrorDomain;

typedef void (^MSTUploadHelperCompletion)(NSString *_Nullable url,
                                          NSError *_Nullable error);

typedef NS_ENUM(NSInteger, MSTUploadHelperErrorCode) {
  MSTUploadHelperErrorNoHost = 1001,
  MSTUploadHelperErrorEmptyClipboard = 1002,
};

@interface MSTUploadHelper : NSObject

+ (void)uploadFileAtURL:(NSURL *)url
              completion:(MSTUploadHelperCompletion)completion
    NS_SWIFT_NAME(uploadFile(at:completion:));

+ (void)uploadData:(NSData *)data
            filename:(NSString *)filename
           completion:(MSTUploadHelperCompletion)completion
    NS_SWIFT_NAME(uploadData(_:filename:completion:));

+ (void)uploadFromClipboardWithCompletion:
    (MSTUploadHelperCompletion)completion
    NS_SWIFT_NAME(uploadFromClipboard(completion:));

+ (NSError *)missingHostError;
+ (NSError *)emptyClipboardError;

@end

NS_ASSUME_NONNULL_END
