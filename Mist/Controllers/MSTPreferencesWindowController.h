//
//  MSTPreferencesWindowController.h
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSTPreferencesWindowController : NSWindowController

+ (MSTPreferencesWindowController *)sharedController;

- (void)showWindow;
- (void)showHistory;

@end

NS_ASSUME_NONNULL_END
