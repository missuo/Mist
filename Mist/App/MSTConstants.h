//
//  MSTConstants.h
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - UserDefaults Keys

extern NSString * const kMSTHostConfigs;
extern NSString * const kMSTDefaultHostId;
extern NSString * const kMSTOutputFormat;
extern NSString * const kMSTCompressFactor;
extern NSString * const kMSTAppGroupIdentifier;

#pragma mark - Notifications

extern NSNotificationName const MSTConfigDidChangeNotification;
extern NSNotificationName const MSTUploadDidStartNotification;
extern NSNotificationName const MSTUploadDidFinishNotification;
extern NSNotificationName const MSTUploadDidFailNotification;
extern NSNotificationName const MSTUploadProgressNotification;


#pragma mark - Output Format

typedef NS_ENUM(NSInteger, MSTOutputFormat) {
    MSTOutputFormatURL,
    MSTOutputFormatMarkdown,
    MSTOutputFormatHTML,
    MSTOutputFormatUBB
};

NS_ASSUME_NONNULL_END
