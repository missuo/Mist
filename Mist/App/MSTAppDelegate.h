//
//  MSTAppDelegate.h
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSTAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong, readonly) NSStatusItem *statusItem;
@property (nonatomic, assign, readonly) BOOL isUploading;

+ (MSTAppDelegate *)shared;

- (void)openPreferences;
- (void)uploadFromClipboard;
- (void)selectFileToUpload;
- (void)uploadFilesAtPaths:(NSArray<NSString *> *)paths;

@end

NS_ASSUME_NONNULL_END
