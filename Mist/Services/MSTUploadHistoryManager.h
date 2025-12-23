//
//  MSTUploadHistoryManager.h
//  Mist
//
//  Created by Claude on 12/23/25.
//

#import <Foundation/Foundation.h>

@class MSTUploadHistoryItem;
@class MSTS3HostConfig;

NS_ASSUME_NONNULL_BEGIN

extern NSString * const MSTUploadHistoryDidChangeNotification;

@interface MSTUploadHistoryManager : NSObject

@property (nonatomic, strong, readonly, class) MSTUploadHistoryManager *sharedManager;
@property (nonatomic, strong, readonly) NSArray<MSTUploadHistoryItem *> *historyItems;

- (void)addHistoryItemWithFilename:(NSString *)filename
                               url:(NSString *)url
                          shortURL:(nullable NSString *)shortURL
                        hostConfig:(MSTS3HostConfig *)hostConfig
                          fileSize:(NSUInteger)fileSize
                          mimeType:(nullable NSString *)mimeType
                     thumbnailData:(nullable NSData *)thumbnailData;

- (void)removeHistoryItem:(MSTUploadHistoryItem *)item;
- (void)removeHistoryItemWithIdentifier:(NSString *)identifier;
- (void)clearAllHistory;

- (void)saveHistory;
- (void)loadHistory;

@end

NS_ASSUME_NONNULL_END
