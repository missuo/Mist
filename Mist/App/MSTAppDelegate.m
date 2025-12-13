//
//  MSTAppDelegate.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTAppDelegate.h"
#import "MSTConfigManager.h"
#import "MSTConstants.h"
#import "MSTPreferencesWindowController.h"
#import "MSTS3HostConfig.h"
#import "MSTS3Uploader.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <UserNotifications/UserNotifications.h>

@interface MSTAppDelegate () <NSDraggingDestination, NSMenuDelegate,
                              UNUserNotificationCenterDelegate>

@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenu *statusMenu;
@property(nonatomic, strong) NSProgressIndicator *progressIndicator;
@property(nonatomic, assign) BOOL isUploading;
@property(nonatomic, strong) NSMenuItem *uploadMenuItem;
@property(nonatomic, strong) NSMenuItem *hostsMenuItem;
@property(nonatomic, strong) NSMenuItem *formatMenuItem;
@property(nonatomic, strong) NSMenuItem *fullDiskAccessMenuItem;
@property(nonatomic, strong) NSMenuItem *statusInfoMenuItem;

// Batch upload tracking
@property(nonatomic, strong, nullable) NSMutableArray<NSString *> *batchUploadURLs;
@property(nonatomic, assign) NSInteger batchUploadTotal;
@property(nonatomic, assign) NSInteger batchUploadCompleted;

@end

@implementation MSTAppDelegate

static MSTAppDelegate *_shared = nil;

+ (MSTAppDelegate *)shared {
  return _shared;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  _shared = self;

  [self setupMainMenu];
  [self setupStatusBar];
  [self setupMenu];
  [self registerNotifications];
  [self requestNotificationPermission];
  
  // Register for URL events
  [[NSAppleEventManager sharedAppleEventManager]
      setEventHandler:self
          andSelector:@selector(handleURLEvent:withReplyEvent:)
        forEventClass:kInternetEventClass
           andEventID:kAEGetURL];
}

#pragma mark - URL Scheme Handler

- (void)handleURLEvent:(NSAppleEventDescriptor *)event
        withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
  NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
  NSLog(@"[Mist] Received URL: %@", urlString);
  
  NSURL *url = [NSURL URLWithString:urlString];
  if (!url || ![url.scheme isEqualToString:@"mist"]) {
    return;
  }
  
  // Handle mist://files?path1,path2,path3
  if ([url.host isEqualToString:@"files"]) {
    NSString *query = url.query;
    if (query.length > 0) {
      NSString *decodedQuery = [query stringByRemovingPercentEncoding];
      NSArray<NSString *> *paths = [decodedQuery componentsSeparatedByString:@","];
      NSLog(@"[Mist] Files to upload: %@", paths);
      [self uploadFilesAtPaths:paths];
    }
  }
}

- (void)uploadFilesAtPaths:(NSArray<NSString *> *)paths {
  if (paths.count == 0) {
    return;
  }
  
  // Initialize batch upload tracking
  self.batchUploadURLs = [NSMutableArray array];
  self.batchUploadTotal = paths.count;
  self.batchUploadCompleted = 0;
  
  // Upload all files
  for (NSString *path in paths) {
    NSString *decodedPath = [path stringByRemovingPercentEncoding];
    NSURL *fileURL = [NSURL fileURLWithPath:decodedPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:decodedPath]) {
      [self uploadFileAtURLInBatch:fileURL];
    } else {
      NSLog(@"[Mist] File not found: %@", decodedPath);
      [self showNotificationWithTitle:@"File Not Found"
                              message:[NSString stringWithFormat:@"Cannot access: %@", decodedPath]];
      // Count as completed (failed)
      self.batchUploadCompleted++;
      [self checkBatchUploadCompletion];
    }
  }
}

- (void)uploadFileAtURLInBatch:(NSURL *)url {
  MSTS3HostConfig *config = [MSTConfigManager sharedManager].defaultHost;
  if (!config) {
    [self showNotificationWithTitle:@"No Host"
                            message:@"Please configure a host first"];
    self.statusInfoMenuItem.title = @"Upload failed: No host configured";
    self.batchUploadCompleted++;
    [self checkBatchUploadCompletion];
    return;
  }

  NSLog(@"[Mist] Upload starting for %@", url.path);

  [[MSTS3Uploader sharedUploader]
      uploadFileAtURL:url
           withConfig:config
             progress:nil
           completion:^(NSString *resultURL, NSError *error) {
             dispatch_async(dispatch_get_main_queue(), ^{
               if (resultURL) {
                 [self.batchUploadURLs addObject:resultURL];
               }
               self.batchUploadCompleted++;
               [self checkBatchUploadCompletion];
             });
           }];
}

- (void)checkBatchUploadCompletion {
  if (self.batchUploadCompleted >= self.batchUploadTotal) {
    // All uploads completed
    NSInteger successCount = self.batchUploadURLs.count;
    NSInteger failedCount = self.batchUploadTotal - successCount;
    
    if (successCount > 0) {
      // Format all URLs
      NSMutableArray *formattedURLs = [NSMutableArray array];
      for (NSString *url in self.batchUploadURLs) {
        NSString *formatted = [[MSTConfigManager sharedManager] formatURL:url];
        [formattedURLs addObject:formatted];
      }
      
      // Join with newlines
      NSString *allURLs = [formattedURLs componentsJoinedByString:@"\n"];
      [self copyToClipboard:allURLs];
      
      // Show notification
      NSString *message;
      if (self.batchUploadTotal == 1) {
        message = self.batchUploadURLs.firstObject;
      } else if (failedCount > 0) {
        message = [NSString stringWithFormat:@"Uploaded %ld/%ld files", 
                   (long)successCount, (long)self.batchUploadTotal];
      } else {
        message = [NSString stringWithFormat:@"Uploaded %ld files", (long)successCount];
      }
      [self showNotificationWithTitle:@"Upload Successful" message:message];
      self.statusInfoMenuItem.title = [NSString stringWithFormat:@"Uploaded %ld/%ld files", 
                                       (long)successCount, (long)self.batchUploadTotal];
    } else {
      // All failed
      [self showNotificationWithTitle:@"Upload Failed" 
                              message:@"All uploads failed"];
      self.statusInfoMenuItem.title = @"Upload failed";
    }
    
    // Reset batch tracking
    self.batchUploadURLs = nil;
    self.batchUploadTotal = 0;
    self.batchUploadCompleted = 0;
  }
}

- (void)setupMainMenu {
  // Create main menu bar for keyboard shortcuts (Cmd+C, Cmd+V, etc.)
  NSMenu *mainMenu = [[NSMenu alloc] init];

  // App menu
  NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
  NSMenu *appMenu = [[NSMenu alloc] init];
  [appMenu addItemWithTitle:@"About Mist"
                     action:@selector(orderFrontStandardAboutPanel:)
              keyEquivalent:@""];
  [appMenu addItem:[NSMenuItem separatorItem]];
  [appMenu addItemWithTitle:@"Hide Mist"
                     action:@selector(hide:)
              keyEquivalent:@"h"];
  [appMenu addItemWithTitle:@"Hide Others"
                     action:@selector(hideOtherApplications:)
              keyEquivalent:@"h"]
      .keyEquivalentModifierMask =
      NSEventModifierFlagCommand | NSEventModifierFlagOption;
  [appMenu addItemWithTitle:@"Show All"
                     action:@selector(unhideAllApplications:)
              keyEquivalent:@""];
  [appMenu addItem:[NSMenuItem separatorItem]];
  [appMenu addItemWithTitle:@"Quit Mist"
                     action:@selector(terminate:)
              keyEquivalent:@"q"];
  appMenuItem.submenu = appMenu;
  [mainMenu addItem:appMenuItem];

  // Edit menu (for Cmd+C, Cmd+V, Cmd+X, Cmd+A, Cmd+Z)
  NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
  NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
  [editMenu addItemWithTitle:@"Undo"
                      action:NSSelectorFromString(@"undo:")
               keyEquivalent:@"z"];
  [editMenu addItemWithTitle:@"Redo"
                      action:NSSelectorFromString(@"redo:")
               keyEquivalent:@"Z"];
  [editMenu addItem:[NSMenuItem separatorItem]];
  [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  [editMenu addItemWithTitle:@"Copy"
                      action:@selector(copy:)
               keyEquivalent:@"c"];
  [editMenu addItemWithTitle:@"Paste"
                      action:@selector(paste:)
               keyEquivalent:@"v"];
  [editMenu addItemWithTitle:@"Select All"
                      action:@selector(selectAll:)
               keyEquivalent:@"a"];
  editMenuItem.submenu = editMenu;
  [mainMenu addItem:editMenuItem];

  [NSApp setMainMenu:mainMenu];
}

- (void)requestNotificationPermission {
  UNUserNotificationCenter *center =
      [UNUserNotificationCenter currentNotificationCenter];
  center.delegate = self;
  [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert |
                                           UNAuthorizationOptionSound |
                                           UNAuthorizationOptionBadge)
                        completionHandler:^(BOOL granted,
                                            NSError *_Nullable error) {
                          if (granted) {
                            NSLog(@"Notification permission granted");
                          } else if (error) {
                            NSLog(@"Notification permission error: %@",
                                  error.localizedDescription);
                          }
                        }];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:
             (void (^)(UNNotificationPresentationOptions))completionHandler {
  // Show notification even when app is in foreground
  completionHandler(UNNotificationPresentationOptionBanner |
                    UNNotificationPresentationOptionSound);
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Status Bar Setup

- (void)setupStatusBar {
  self.statusItem = [[NSStatusBar systemStatusBar]
      statusItemWithLength:NSSquareStatusItemLength];

  NSImage *icon = [NSImage imageWithSystemSymbolName:@"cloud.fill"
                            accessibilityDescription:@"Mist"];
  // Configure icon to match standard menu bar size
  NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration
      configurationWithPointSize:16
                          weight:NSFontWeightRegular
                           scale:NSImageSymbolScaleMedium];
  icon = [icon imageWithSymbolConfiguration:config];
  icon.template = YES;

  self.statusItem.button.image = icon;
  self.statusItem.button.imagePosition = NSImageOnly;

  // Setup drag and drop
  [self.statusItem.button.window registerForDraggedTypes:@[
    NSPasteboardTypeFileURL, NSPasteboardTypePNG, NSPasteboardTypeTIFF
  ]];
  self.statusItem.button.window.delegate = (id<NSWindowDelegate>)self;

  // Setup progress indicator
  self.progressIndicator =
      [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(2, 2, 18, 18)];
  self.progressIndicator.style = NSProgressIndicatorStyleSpinning;
  self.progressIndicator.controlSize = NSControlSizeSmall;
  self.progressIndicator.hidden = YES;
  [self.statusItem.button addSubview:self.progressIndicator];
}

- (void)setupMenu {
  self.statusMenu = [[NSMenu alloc] init];
  self.statusMenu.delegate = self;

  // Full Disk Access status
  self.fullDiskAccessMenuItem =
      [[NSMenuItem alloc] initWithTitle:@"Checking Full Disk Access..."
                                 action:nil
                          keyEquivalent:@""]; 
  [self.statusMenu addItem:self.fullDiskAccessMenuItem];
  [self updateFullDiskAccessMenuItem];

  // Upload status info
  self.statusInfoMenuItem = [[NSMenuItem alloc] initWithTitle:@"Ready"
                                                       action:nil
                                                keyEquivalent:@""];
  [self.statusMenu addItem:self.statusInfoMenuItem];

  [self.statusMenu addItem:[NSMenuItem separatorItem]];

  // Upload from clipboard
  self.uploadMenuItem =
      [[NSMenuItem alloc] initWithTitle:@"Upload from Clipboard"
                                 action:@selector(uploadFromClipboard)
                          keyEquivalent:@""];
  self.uploadMenuItem.target = self;
  [self.statusMenu addItem:self.uploadMenuItem];

  // Select file
  NSMenuItem *selectFileItem =
      [[NSMenuItem alloc] initWithTitle:@"Select File..."
                                 action:@selector(selectFileToUpload)
                          keyEquivalent:@""];
  selectFileItem.target = self;
  [self.statusMenu addItem:selectFileItem];

  [self.statusMenu addItem:[NSMenuItem separatorItem]];

  // Hosts submenu
  self.hostsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Host"
                                                  action:nil
                                           keyEquivalent:@""];
  NSMenu *hostsSubmenu = [[NSMenu alloc] init];
  self.hostsMenuItem.submenu = hostsSubmenu;
  [self.statusMenu addItem:self.hostsMenuItem];
  [self updateHostsMenu];
  [self updateHostsMenuTitle];

  // Output format submenu
  self.formatMenuItem = [[NSMenuItem alloc] initWithTitle:@"Output Format"
                                                   action:nil
                                            keyEquivalent:@""];
  NSMenu *formatSubmenu = [[NSMenu alloc] init];
  formatSubmenu.delegate = self;

  NSMenuItem *urlFormat =
      [[NSMenuItem alloc] initWithTitle:@"URL"
                                 action:@selector(setOutputFormat:)
                          keyEquivalent:@""];
  urlFormat.target = self;
  urlFormat.tag = MSTOutputFormatURL;
  [formatSubmenu addItem:urlFormat];

  NSMenuItem *mdFormat =
      [[NSMenuItem alloc] initWithTitle:@"Markdown"
                                 action:@selector(setOutputFormat:)
                          keyEquivalent:@""];
  mdFormat.target = self;
  mdFormat.tag = MSTOutputFormatMarkdown;
  [formatSubmenu addItem:mdFormat];

  NSMenuItem *htmlFormat =
      [[NSMenuItem alloc] initWithTitle:@"HTML"
                                 action:@selector(setOutputFormat:)
                          keyEquivalent:@""];
  htmlFormat.target = self;
  htmlFormat.tag = MSTOutputFormatHTML;
  [formatSubmenu addItem:htmlFormat];

  NSMenuItem *ubbFormat =
      [[NSMenuItem alloc] initWithTitle:@"UBB"
                                 action:@selector(setOutputFormat:)
                          keyEquivalent:@""];
  ubbFormat.target = self;
  ubbFormat.tag = MSTOutputFormatUBB;
  [formatSubmenu addItem:ubbFormat];

  self.formatMenuItem.submenu = formatSubmenu;
  [self.statusMenu addItem:self.formatMenuItem];
  [self updateFormatMenuTitle];

  [self.statusMenu addItem:[NSMenuItem separatorItem]];

  // Preferences
  NSMenuItem *prefsItem =
      [[NSMenuItem alloc] initWithTitle:@"Preferences..."
                                 action:@selector(openPreferences)
                          keyEquivalent:@","];
  prefsItem.target = self;
  [self.statusMenu addItem:prefsItem];

  [self.statusMenu addItem:[NSMenuItem separatorItem]];

  // Quit
  NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                    action:@selector(quit)
                                             keyEquivalent:@"q"];
  quitItem.target = self;
  [self.statusMenu addItem:quitItem];

  self.statusItem.menu = self.statusMenu;
}

- (void)updateHostsMenu {
  NSMenu *hostsSubmenu = [[NSMenu alloc] init];

  NSArray<MSTS3HostConfig *> *configs =
      [MSTConfigManager sharedManager].hostConfigs;

  if (configs.count == 0) {
    NSMenuItem *noHostItem =
        [[NSMenuItem alloc] initWithTitle:@"No hosts configured"
                                   action:nil
                            keyEquivalent:@""];
    noHostItem.enabled = NO;
    [hostsSubmenu addItem:noHostItem];
  } else {
    for (MSTS3HostConfig *config in configs) {
      NSMenuItem *item =
          [[NSMenuItem alloc] initWithTitle:config.name
                                     action:@selector(selectHost:)
                              keyEquivalent:@""];
      item.target = self;
      item.representedObject = config.identifier;

      if (config.isDefault) {
        item.state = NSControlStateValueOn;
      }

      [hostsSubmenu addItem:item];
    }
  }

  self.hostsMenuItem.submenu = hostsSubmenu;
}

- (void)updateHostsMenuTitle {
  MSTS3HostConfig *defaultHost = [MSTConfigManager sharedManager].defaultHost;
  if (defaultHost) {
    self.hostsMenuItem.title = [NSString stringWithFormat:@"Host: %@", defaultHost.name];
  } else {
    self.hostsMenuItem.title = @"Host";
  }
}

- (void)updateFormatMenuTitle {
  MSTOutputFormat format = [MSTConfigManager sharedManager].outputFormat;
  NSString *formatName;
  
  switch (format) {
    case MSTOutputFormatURL:
      formatName = @"URL";
      break;
    case MSTOutputFormatMarkdown:
      formatName = @"Markdown";
      break;
    case MSTOutputFormatHTML:
      formatName = @"HTML";
      break;
    case MSTOutputFormatUBB:
      formatName = @"UBB";
      break;
    default:
      formatName = @"URL";
      break;
  }
  
  self.formatMenuItem.title = [NSString stringWithFormat:@"Output Format: %@", formatName];
}

#pragma mark - Notifications

- (void)registerNotifications {
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(configDidChange:)
             name:MSTConfigDidChangeNotification
           object:nil];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(uploadDidStart:)
             name:MSTUploadDidStartNotification
           object:nil];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(uploadDidFinish:)
             name:MSTUploadDidFinishNotification
           object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(uploadDidFail:)
                                               name:MSTUploadDidFailNotification
                                             object:nil];
}

- (void)configDidChange:(NSNotification *)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self updateHostsMenu];
    [self updateHostsMenuTitle];
  });
}

- (void)uploadDidStart:(NSNotification *)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
    self.isUploading = YES;
    self.statusItem.button.image = nil;
    self.progressIndicator.hidden = NO;
    [self.progressIndicator startAnimation:nil];

    self.statusInfoMenuItem.title = @"Uploading...";
  });
}

- (void)uploadDidFinish:(NSNotification *)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
    self.isUploading = NO;
    [self.progressIndicator stopAnimation:nil];
    self.progressIndicator.hidden = YES;

    NSImage *icon = [NSImage imageWithSystemSymbolName:@"cloud.fill"
                              accessibilityDescription:@"Mist"];
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration
        configurationWithPointSize:16
                            weight:NSFontWeightRegular
                             scale:NSImageSymbolScaleMedium];
    icon = [icon imageWithSymbolConfiguration:config];
    icon.template = YES;
    self.statusItem.button.image = icon;

    // Only handle single file uploads here (not batch uploads)
    if (self.batchUploadURLs == nil) {
      NSString *url = notification.userInfo[@"url"];
      if (url) {
        NSString *formattedURL = [[MSTConfigManager sharedManager] formatURL:url];
        [self copyToClipboard:formattedURL];
        [self showNotificationWithTitle:@"Upload Successful" message:url];
        self.statusInfoMenuItem.title = @"Upload successful";
      }
    } else {
      self.statusInfoMenuItem.title = [NSString stringWithFormat:@"Uploading %ld/%ld files", 
                                       (long)self.batchUploadCompleted, 
                                       (long)self.batchUploadTotal];
    }
  });
}

- (void)uploadDidFail:(NSNotification *)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
    self.isUploading = NO;
    [self.progressIndicator stopAnimation:nil];
    self.progressIndicator.hidden = YES;

    NSImage *icon = [NSImage imageWithSystemSymbolName:@"cloud.fill"
                              accessibilityDescription:@"Mist"];
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration
        configurationWithPointSize:16
                            weight:NSFontWeightRegular
                             scale:NSImageSymbolScaleMedium];
    icon = [icon imageWithSymbolConfiguration:config];
    icon.template = YES;
    self.statusItem.button.image = icon;

    NSError *error = notification.userInfo[@"error"];
    
    // Only show individual error notifications for single uploads
    if (self.batchUploadURLs == nil) {
      [self showNotificationWithTitle:@"Upload Failed"
                              message:error.localizedDescription
                                          ?: @"Unknown error"];
      if (error.localizedDescription.length > 0) {
        self.statusInfoMenuItem.title =
            [NSString stringWithFormat:@"Upload failed: %@",
                                       error.localizedDescription];
      } else {
        self.statusInfoMenuItem.title = @"Upload failed";
      }
    }
  });
}

#pragma mark - Actions

- (void)openPreferences {
  [[MSTPreferencesWindowController sharedController] showWindow];
}

- (void)uploadFromClipboard {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];

  // Check for image data
  NSData *imageData = nil;
  NSString *filename = nil;

  if ([pasteboard
          canReadItemWithDataConformingToTypes:@[ NSPasteboardTypePNG ]]) {
    imageData = [pasteboard dataForType:NSPasteboardTypePNG];
    filename =
        [NSString stringWithFormat:@"clipboard_%ld.png",
                                   (long)[[NSDate date] timeIntervalSince1970]];
  } else if ([pasteboard canReadItemWithDataConformingToTypes:@[
               NSPasteboardTypeTIFF
             ]]) {
    NSData *tiffData = [pasteboard dataForType:NSPasteboardTypeTIFF];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:tiffData];
    imageData = [imageRep representationUsingType:NSBitmapImageFileTypePNG
                                       properties:@{}];
    filename =
        [NSString stringWithFormat:@"clipboard_%ld.png",
                                   (long)[[NSDate date] timeIntervalSince1970]];
  } else if ([pasteboard canReadItemWithDataConformingToTypes:@[
               NSPasteboardTypeFileURL
             ]]) {
    NSArray *urls = [pasteboard
        readObjectsForClasses:@[ [NSURL class] ]
                      options:@{NSPasteboardURLReadingFileURLsOnlyKey : @YES}];
    if (urls.count > 0) {
      [self uploadFileAtURL:urls.firstObject];
      return;
    }
  }

  if (imageData && filename) {
    [self uploadData:imageData filename:filename];
  } else {
    [self showNotificationWithTitle:@"No Image"
                            message:@"No image found in clipboard"];
  }
}

- (void)selectFileToUpload {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.allowsMultipleSelection = NO;
  panel.canChooseDirectories = NO;
  panel.canChooseFiles = YES;
  panel.allowedContentTypes = @[
    [UTType typeWithIdentifier:@"public.image"],
    [UTType typeWithIdentifier:@"public.movie"],
    [UTType typeWithIdentifier:@"public.data"]
  ];

  [panel beginWithCompletionHandler:^(NSModalResponse result) {
    if (result == NSModalResponseOK && panel.URLs.count > 0) {
      [self uploadFileAtURL:panel.URLs.firstObject];
    }
  }];
}

- (void)selectHost:(NSMenuItem *)sender {
  NSString *identifier = sender.representedObject;
  [[MSTConfigManager sharedManager] setDefaultHostWithIdentifier:identifier];
  [self updateHostsMenuTitle];
}

- (void)setOutputFormat:(NSMenuItem *)sender {
  [MSTConfigManager sharedManager].outputFormat = sender.tag;
  [[MSTConfigManager sharedManager] saveConfigs];
  [self updateFormatMenuTitle];
}

- (void)quit {
  [[NSApplication sharedApplication] terminate:nil];
}

#pragma mark - Upload Helpers

- (void)uploadFileAtURL:(NSURL *)url {
  MSTS3HostConfig *config = [MSTConfigManager sharedManager].defaultHost;
  if (!config) {
    [self showNotificationWithTitle:@"No Host"
                            message:@"Please configure a host first"];
    self.statusInfoMenuItem.title = @"Upload failed: No host configured";
    return;
  }

  NSLog(@"[Mist] Upload starting for %@", url.path);

  [[MSTS3Uploader sharedUploader]
      uploadFileAtURL:url
           withConfig:config
             progress:nil
           completion:^(NSString *url, NSError *error){
               // Notification handlers will take care of UI updates
           }];
}

- (void)uploadData:(NSData *)data filename:(NSString *)filename {
  MSTS3HostConfig *config = [MSTConfigManager sharedManager].defaultHost;
  if (!config) {
    [self showNotificationWithTitle:@"No Host"
                            message:@"Please configure a host first"];
    return;
  }

  [[MSTS3Uploader sharedUploader]
      uploadData:data
        filename:filename
      withConfig:config
        progress:nil
      completion:^(NSString *url, NSError *error){
          // Notification handlers will take care of UI updates
      }];
}

#pragma mark - Full Disk Access

- (BOOL)hasFullDiskAccess {
  NSError *error = nil;
  NSString *tccPath = @"/Library/Application Support/com.apple.TCC/TCC.db";
  [NSData dataWithContentsOfFile:tccPath
                         options:NSDataReadingMappedIfSafe
                           error:&error];
  if (!error) {
    return YES;
  }

  if (error.code == NSFileReadNoPermissionError) {
    return NO;
  }

  error = nil;
  NSString *mailPath =
      [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Mail"];
  [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mailPath
                                                       error:&error];

  if (!error) {
    return YES;
  }

  if (error.code == NSFileReadNoPermissionError) {
    return NO;
  }

  return NO;
}

- (void)updateFullDiskAccessMenuItem {
  BOOL granted = [self hasFullDiskAccess];
  if (!self.fullDiskAccessMenuItem) {
    return;
  }

  if (granted) {
    self.fullDiskAccessMenuItem.title = @"Full Disk Access: Granted";
    self.fullDiskAccessMenuItem.action = nil;
    self.fullDiskAccessMenuItem.target = nil;
    self.fullDiskAccessMenuItem.enabled = NO;
  } else {
    self.fullDiskAccessMenuItem.title = @"Grant Full Disk Access...";
    self.fullDiskAccessMenuItem.action = @selector(openFullDiskAccessPreferences);
    self.fullDiskAccessMenuItem.target = self;
    self.fullDiskAccessMenuItem.enabled = YES;
  }
}

- (void)openFullDiskAccessPreferences {
  NSURL *url = [NSURL
      URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark - Utilities

- (void)copyToClipboard:(NSString *)string {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard setString:string forType:NSPasteboardTypeString];
}

- (void)showNotificationWithTitle:(NSString *)title
                          message:(NSString *)message {
  UNMutableNotificationContent *content =
      [[UNMutableNotificationContent alloc] init];
  content.title = title;
  content.body = message;
  content.sound = [UNNotificationSound defaultSound];

  UNNotificationRequest *request =
      [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                           content:content
                                           trigger:nil];

  [[UNUserNotificationCenter currentNotificationCenter]
      addNotificationRequest:request
       withCompletionHandler:nil];
}

#pragma mark - Drag and Drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
  NSPasteboard *pasteboard = sender.draggingPasteboard;

  NSArray *urls = [pasteboard
      readObjectsForClasses:@[ [NSURL class] ]
                    options:@{NSPasteboardURLReadingFileURLsOnlyKey : @YES}];

  if (urls.count > 0) {
    [self uploadFileAtURL:urls.firstObject];
    return YES;
  }

  return NO;
}

#pragma mark - NSMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu {
  if (menu == self.statusMenu) {
    [self updateFullDiskAccessMenuItem];
  }

  if (menu == self.formatMenuItem.submenu) {
    MSTOutputFormat currentFormat =
        [MSTConfigManager sharedManager].outputFormat;
    for (NSMenuItem *item in menu.itemArray) {
      item.state = (item.tag == currentFormat) ? NSControlStateValueOn
                                               : NSControlStateValueOff;
    }
  }
}

@end
