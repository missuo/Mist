//
//  MSTImageProcessor.h
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSTImageProcessor : NSObject

+ (BOOL)isImageFile:(NSString *)filename;
+ (NSData *)processImageDataIfNeeded:(NSData *)data filename:(NSString *)filename;

@end

NS_ASSUME_NONNULL_END
