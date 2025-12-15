//
//  MSTUploadUtilities.h
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSTUploadUtilities : NSObject

+ (NSString *)uriEncode:(NSString *)string encodeSlash:(BOOL)encodeSlash;
+ (NSString *)mimeTypeForFilename:(NSString *)filename;
+ (NSString *)generateSaveKeyWithTemplate:(NSString *)templateString
                                 filename:(NSString *)filename;
+ (nullable NSString *)extractRegionFromB2Endpoint:(NSString *)host;

@end

NS_ASSUME_NONNULL_END
