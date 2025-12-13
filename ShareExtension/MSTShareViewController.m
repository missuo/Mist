//
//  MSTShareViewController.m
//  Mist Share Extension
//
//  Created by Factory Droid.
//

#import "MSTShareViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MSTShareViewController ()

@property(nonatomic, strong) NSProgressIndicator *indicator;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSButton *okButton;

@end

@implementation MSTShareViewController

- (void)loadView {
  NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 100)];

  self.indicator = [[NSProgressIndicator alloc]
      initWithFrame:NSMakeRect(140, 55, 20, 20)];
  self.indicator.style = NSProgressIndicatorStyleSpinning;
  self.indicator.controlSize = NSControlSizeRegular;
  [self.indicator startAnimation:nil];
  [container addSubview:self.indicator];

  self.statusLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(20, 25, container.bounds.size.width - 40, 20)];
  self.statusLabel.bezeled = NO;
  self.statusLabel.drawsBackground = NO;
  self.statusLabel.editable = NO;
  self.statusLabel.selectable = NO;
  self.statusLabel.alignment = NSTextAlignmentCenter;
  self.statusLabel.stringValue = @"Processing files...";
  [container addSubview:self.statusLabel];

  self.okButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(container.bounds.size.width - 80,
                               container.bounds.size.height - 30, 60, 24)];
  self.okButton.title = @"OK";
  self.okButton.bezelStyle = NSBezelStyleRounded;
  self.okButton.target = self;
  self.okButton.action = @selector(okButtonClicked:);
  self.okButton.hidden = YES;
  [container addSubview:self.okButton];

  self.view = container;

  // Start processing files
  [self processSelectedFiles];
}

- (void)processSelectedFiles {
  NSExtensionContext *context = self.extensionContext;
  
  if (!context || context.inputItems.count == 0) {
    [self showError:@"No files selected"];
    return;
  }

  NSExtensionItem *item = context.inputItems.firstObject;
  NSArray<NSItemProvider *> *attachments = item.attachments;
  
  if (!attachments || attachments.count == 0) {
    [self showError:@"No attachments found"];
    return;
  }

  NSMutableArray<NSString *> *filePaths = [NSMutableArray array];
  __block NSInteger processedCount = 0;
  NSInteger totalCount = attachments.count;

  for (NSItemProvider *provider in attachments) {
    // Try public.file-url first, then public.url
    NSString *typeIdentifier = nil;
    
    if ([provider hasItemConformingToTypeIdentifier:@"public.file-url"]) {
      typeIdentifier = @"public.file-url";
    } else if ([provider hasItemConformingToTypeIdentifier:@"public.url"]) {
      typeIdentifier = @"public.url";
    }
    
    if (typeIdentifier) {
      [provider loadItemForTypeIdentifier:typeIdentifier
                                  options:nil
                        completionHandler:^(id<NSSecureCoding> data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
          processedCount++;
          
          if (!error && data) {
            NSURL *fileURL = nil;
            NSObject *object = (NSObject *)data;
            
            if ([object isKindOfClass:[NSURL class]]) {
              fileURL = (NSURL *)object;
            } else if ([object isKindOfClass:[NSData class]]) {
              NSData *bookmarkData = (NSData *)object;
              fileURL = [NSURL URLByResolvingBookmarkData:bookmarkData
                                                 options:0
                                           relativeToURL:nil
                                     bookmarkDataIsStale:nil
                                                   error:nil];
              if (!fileURL) {
                fileURL = [NSURL URLWithDataRepresentation:bookmarkData relativeToURL:nil];
              }
            }
            
            if (fileURL && fileURL.isFileURL) {
              NSString *path = fileURL.path;
              if (path.length > 0) {
                [filePaths addObject:path];
                NSLog(@"[MistShareExtension] Got file path: %@", path);
              }
            }
          } else if (error) {
            NSLog(@"[MistShareExtension] Error loading item: %@", error);
          }
          
          // Check if all items processed
          if (processedCount == totalCount) {
            [self finishWithFilePaths:filePaths];
          }
        });
      }];
    } else {
      processedCount++;
      NSLog(@"[MistShareExtension] Unsupported provider types: %@", provider.registeredTypeIdentifiers);
      
      if (processedCount == totalCount) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self finishWithFilePaths:filePaths];
        });
      }
    }
  }
}

- (void)finishWithFilePaths:(NSArray<NSString *> *)filePaths {
  if (filePaths.count == 0) {
    [self showError:@"No valid files found"];
    return;
  }

  // Update UI
  self.statusLabel.stringValue = @"Launching Mist...";

  // Build URL with file paths
  NSMutableArray<NSString *> *encodedPaths = [NSMutableArray array];
  for (NSString *path in filePaths) {
    NSString *encoded = [path stringByAddingPercentEncodingWithAllowedCharacters:
                         [NSCharacterSet URLQueryAllowedCharacterSet]];
    if (encoded) {
      [encodedPaths addObject:encoded];
    }
  }

  NSString *pathsParam = [encodedPaths componentsJoinedByString:@","];
  NSString *urlString = [NSString stringWithFormat:@"mist://files?%@", pathsParam];
  NSURL *url = [NSURL URLWithString:urlString];

  NSLog(@"[MistShareExtension] Opening URL: %@", urlString);

  if (url) {
    [[NSWorkspace sharedWorkspace] openURL:url];
    
    // Close extension after short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [self closeExtension];
    });
  } else {
    [self showError:@"Failed to create URL"];
  }
}

- (void)showError:(NSString *)message {
  [self.indicator stopAnimation:nil];
  self.indicator.hidden = YES;
  self.statusLabel.stringValue = message;
  self.okButton.hidden = NO;
}

- (void)okButtonClicked:(id)sender {
  [self closeExtension];
}

- (void)closeExtension {
  NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                       code:NSUserCancelledError
                                   userInfo:nil];
  [self.extensionContext cancelRequestWithError:error];
}

@end
