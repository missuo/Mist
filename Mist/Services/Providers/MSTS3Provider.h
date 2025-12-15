//
//  MSTS3Provider.h
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import <Foundation/Foundation.h>
#import "MSTUploadProvider.h"

NS_ASSUME_NONNULL_BEGIN

/// Provider for all S3-compatible services (AWS, Wasabi, Cloudflare R2, Backblaze B2, MinIO, Custom)
@interface MSTS3Provider : NSObject <MSTUploadProvider>

@end

NS_ASSUME_NONNULL_END
