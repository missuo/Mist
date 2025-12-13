//
//  MSTS3ConfigViewController.h
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import <Cocoa/Cocoa.h>

@class MSTS3HostConfig;

NS_ASSUME_NONNULL_BEGIN

@interface MSTS3ConfigViewController : NSViewController

@property (nonatomic, strong, nullable) MSTS3HostConfig *config;

- (void)setConfig:(nullable MSTS3HostConfig *)config;

@end

NS_ASSUME_NONNULL_END
