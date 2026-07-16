//
//  MSTUploadHistoryItem.h
//  Mist
//
//  Created by Claude on 12/23/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSTUploadHistoryItem : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *hostName;
@property (nonatomic, copy) NSString *hostIdentifier;
@property (nonatomic, strong) NSDate *uploadDate;
@property (nonatomic, assign) NSUInteger fileSize;
@property (nonatomic, copy, nullable) NSString *mimeType;
@property (nonatomic, strong, nullable) NSData *thumbnailData;

- (instancetype)init;
- (instancetype)initWithIdentifier:(NSString *)identifier NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
