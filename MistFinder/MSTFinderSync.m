//
//  MSTFinderSync.m
//  MistFinder
//
//  Created by Vincent Yang on 7/16/26.
//

#import "MSTFinderSync.h"
#import <AppKit/AppKit.h>

@implementation MSTFinderSync

- (instancetype)init {
  self = [super init];
  if (self) {
    // Watch the whole filesystem so the menu item is offered for any
    // Finder selection, not just specific folders.
    FIFinderSyncController.defaultController.directoryURLs =
        [NSSet setWithObject:[NSURL fileURLWithPath:@"/"]];
  }
  return self;
}

#pragma mark - Menu

- (NSMenu *)menuForMenuKind:(FIMenuKind)menuKind {
  if (menuKind != FIMenuKindContextualMenuForItems) {
    return nil;
  }

  NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
  NSMenuItem *item = [menu addItemWithTitle:@"Upload to Mist"
                                     action:@selector(uploadToMist:)
                              keyEquivalent:@""];
  item.image = [NSImage imageWithSystemSymbolName:@"cloud.fill"
                         accessibilityDescription:@"Upload to Mist"];
  return menu;
}

- (void)uploadToMist:(id)sender {
  NSArray<NSURL *> *items =
      FIFinderSyncController.defaultController.selectedItemURLs;
  if (items.count == 0) {
    return;
  }

  // Percent-encode each path and join with commas; the main app's
  // mist://files handler splits on "," and removes percent-encoding.
  NSMutableCharacterSet *allowed =
      [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
  [allowed removeCharactersInString:@",&%"];

  NSMutableArray<NSString *> *encodedPaths = [NSMutableArray array];
  for (NSURL *url in items) {
    NSString *encoded = [url.path
        stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    if (encoded.length > 0) {
      [encodedPaths addObject:encoded];
    }
  }
  if (encodedPaths.count == 0) {
    return;
  }

  NSString *urlString =
      [NSString stringWithFormat:@"mist://files?%@",
                                 [encodedPaths componentsJoinedByString:@","]];
  NSURL *url = [NSURL URLWithString:urlString];
  if (url) {
    [[NSWorkspace sharedWorkspace] openURL:url];
  }
}

@end
