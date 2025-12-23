//
//  MSTPreferencesWindowController.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTPreferencesWindowController.h"
#import "MSTHostsViewController.h"
#import "MSTGeneralViewController.h"
#import "MSTHistoryViewController.h"
#import "MSTAboutViewController.h"

@interface MSTPreferencesWindowController () <NSToolbarDelegate>

@property (nonatomic, strong) NSToolbar *toolbar;
@property (nonatomic, strong) MSTHostsViewController *hostsVC;
@property (nonatomic, strong) MSTGeneralViewController *generalVC;
@property (nonatomic, strong) MSTHistoryViewController *historyVC;
@property (nonatomic, strong) MSTAboutViewController *aboutVC;
@property (nonatomic, copy) NSString *currentIdentifier;

@end

@implementation MSTPreferencesWindowController

static MSTPreferencesWindowController *_sharedController = nil;

+ (MSTPreferencesWindowController *)sharedController {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedController = [[MSTPreferencesWindowController alloc] init];
    });
    return _sharedController;
}

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 400)
                                                   styleMask:NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Mist Preferences";
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        [self setupToolbar];
        [self setupViewControllers];
        [self switchToIdentifier:@"hosts"];
    }
    return self;
}

- (void)setupToolbar {
    self.toolbar = [[NSToolbar alloc] initWithIdentifier:@"MSTPreferencesToolbar"];
    self.toolbar.delegate = self;
    self.toolbar.allowsUserCustomization = NO;
    self.toolbar.displayMode = NSToolbarDisplayModeIconAndLabel;
    self.window.toolbar = self.toolbar;

    if (@available(macOS 11.0, *)) {
        self.window.toolbarStyle = NSWindowToolbarStylePreference;
    }
}

- (void)setupViewControllers {
    self.hostsVC = [[MSTHostsViewController alloc] init];
    self.generalVC = [[MSTGeneralViewController alloc] init];
    self.historyVC = [[MSTHistoryViewController alloc] init];
    self.aboutVC = [[MSTAboutViewController alloc] init];
}

- (void)showWindow {
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - Toolbar Delegate

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[@"hosts", @"general", @"history", @"about"];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[@"hosts", @"general", @"history", @"about"];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
    return @[@"hosts", @"general", @"history", @"about"];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag {

    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    item.target = self;
    item.action = @selector(toolbarItemClicked:);

    if ([itemIdentifier isEqualToString:@"hosts"]) {
        item.label = @"Hosts";
        item.image = [NSImage imageWithSystemSymbolName:@"server.rack"
                               accessibilityDescription:@"Hosts"];
    } else if ([itemIdentifier isEqualToString:@"general"]) {
        item.label = @"General";
        item.image = [NSImage imageWithSystemSymbolName:@"gear"
                               accessibilityDescription:@"General"];
    } else if ([itemIdentifier isEqualToString:@"history"]) {
        item.label = @"History";
        item.image = [NSImage imageWithSystemSymbolName:@"clock.arrow.circlepath"
                               accessibilityDescription:@"History"];
    } else if ([itemIdentifier isEqualToString:@"about"]) {
        item.label = @"About";
        item.image = [NSImage imageWithSystemSymbolName:@"info.circle"
                               accessibilityDescription:@"About"];
    }

    return item;
}

- (void)toolbarItemClicked:(NSToolbarItem *)sender {
    [self switchToIdentifier:sender.itemIdentifier];
}

- (void)switchToIdentifier:(NSString *)identifier {
    if ([self.currentIdentifier isEqualToString:identifier]) return;

    self.currentIdentifier = identifier;
    [self.toolbar setSelectedItemIdentifier:identifier];

    NSViewController *vc = nil;
    if ([identifier isEqualToString:@"hosts"]) {
        vc = self.hostsVC;
    } else if ([identifier isEqualToString:@"general"]) {
        vc = self.generalVC;
    } else if ([identifier isEqualToString:@"history"]) {
        vc = self.historyVC;
    } else if ([identifier isEqualToString:@"about"]) {
        vc = self.aboutVC;
    }

    if (vc) {
        self.window.contentViewController = vc;

        // Resize window to fit content
        NSSize newSize = vc.preferredContentSize;
        if (newSize.width > 0 && newSize.height > 0) {
            NSRect frame = self.window.frame;
            CGFloat titleBarHeight = frame.size.height - self.window.contentView.frame.size.height;
            frame.size.width = newSize.width;
            frame.size.height = newSize.height + titleBarHeight;
            [self.window setFrame:frame display:YES animate:YES];
        }
    }
}

@end
