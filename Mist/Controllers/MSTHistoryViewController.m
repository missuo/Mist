//
//  MSTHistoryViewController.m
//  Mist
//
//  Created by Claude on 12/23/25.
//

#import "MSTHistoryViewController.h"
#import "MSTUploadHistoryManager.h"
#import "MSTUploadHistoryItem.h"

@interface MSTHistoryViewController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSButton *clearButton;
@property (nonatomic, strong) NSTextField *emptyLabel;
@property (nonatomic, strong) NSArray<MSTUploadHistoryItem *> *historyItems;

// Hover image preview
@property (nonatomic, strong) NSPopover *previewPopover;
@property (nonatomic, strong) NSImageView *previewImageView;
@property (nonatomic, assign) NSInteger previewRow;
@property (nonatomic, strong) NSURLSessionDataTask *previewTask;
@property (nonatomic, strong) NSCache<NSString *, NSImage *> *previewCache;

@end

@implementation MSTHistoryViewController

- (instancetype)init {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    self.preferredContentSize = NSMakeSize(680, 480);
  }
  return self;
}

- (void)loadView {
  self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 680, 480)];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupUI];
  [self loadHistory];
  [self registerNotifications];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUI {
  CGFloat width = self.view.bounds.size.width;
  CGFloat height = self.view.bounds.size.height;

  // Clear button (top right)
  self.clearButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(width - 20 - 90, height - 44, 90, 24)];
  self.clearButton.title = @"Clear All";
  self.clearButton.bezelStyle = NSBezelStyleRounded;
  self.clearButton.target = self;
  self.clearButton.action = @selector(clearAllHistory:);
  self.clearButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  [self.view addSubview:self.clearButton];

  // Table view in scroll view
  self.scrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(20, 20, width - 40, height - 84)];
  self.scrollView.hasVerticalScroller = YES;
  self.scrollView.hasHorizontalScroller = NO;
  self.scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.scrollView.borderType = NSBezelBorder;

  self.tableView = [[NSTableView alloc] initWithFrame:self.scrollView.bounds];
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  self.tableView.rowHeight = 36;
  self.tableView.allowsMultipleSelection = NO;
  self.tableView.usesAlternatingRowBackgroundColors = YES;
  self.tableView.doubleAction = @selector(tableViewDoubleClicked:);
  self.tableView.target = self;

  // Preview column
  NSTableColumn *previewColumn = [[NSTableColumn alloc] initWithIdentifier:@"preview"];
  previewColumn.title = @"";
  previewColumn.width = 40;
  previewColumn.minWidth = 40;
  previewColumn.maxWidth = 40;
  [self.tableView addTableColumn:previewColumn];

  // Filename column
  NSTableColumn *filenameColumn = [[NSTableColumn alloc] initWithIdentifier:@"filename"];
  filenameColumn.title = @"Filename";
  filenameColumn.width = 160;
  filenameColumn.minWidth = 80;
  [self.tableView addTableColumn:filenameColumn];

  // URL column
  NSTableColumn *urlColumn = [[NSTableColumn alloc] initWithIdentifier:@"url"];
  urlColumn.title = @"URL";
  urlColumn.width = 218;
  urlColumn.minWidth = 100;
  [self.tableView addTableColumn:urlColumn];

  // Host column
  NSTableColumn *hostColumn = [[NSTableColumn alloc] initWithIdentifier:@"host"];
  hostColumn.title = @"Host";
  hostColumn.width = 70;
  hostColumn.minWidth = 60;
  [self.tableView addTableColumn:hostColumn];

  // Date column
  NSTableColumn *dateColumn = [[NSTableColumn alloc] initWithIdentifier:@"date"];
  dateColumn.title = @"Date";
  dateColumn.width = 118;
  dateColumn.minWidth = 80;
  [self.tableView addTableColumn:dateColumn];

  self.scrollView.documentView = self.tableView;
  [self.view addSubview:self.scrollView];

  // Empty state label
  self.emptyLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(0, height / 2 - 20, width, 40)];
  self.emptyLabel.stringValue = @"No upload history";
  self.emptyLabel.alignment = NSTextAlignmentCenter;
  self.emptyLabel.bezeled = NO;
  self.emptyLabel.drawsBackground = NO;
  self.emptyLabel.editable = NO;
  self.emptyLabel.textColor = [NSColor secondaryLabelColor];
  self.emptyLabel.font = [NSFont systemFontOfSize:14];
  self.emptyLabel.hidden = YES;
  [self.view addSubview:self.emptyLabel];

  // Context menu
  NSMenu *contextMenu = [[NSMenu alloc] init];
  [contextMenu addItemWithTitle:@"Copy URL" action:@selector(copyURL:) keyEquivalent:@""];
  [contextMenu addItem:[NSMenuItem separatorItem]];
  [contextMenu addItemWithTitle:@"Delete" action:@selector(deleteSelectedItem:) keyEquivalent:@""];
  self.tableView.menu = contextMenu;
}

- (void)registerNotifications {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(historyDidChange:)
                                               name:MSTUploadHistoryDidChangeNotification
                                             object:nil];
}

- (void)loadHistory {
  self.historyItems = [MSTUploadHistoryManager sharedManager].historyItems;
  [self.tableView reloadData];
  [self updateEmptyState];
}

- (void)updateEmptyState {
  BOOL isEmpty = self.historyItems.count == 0;
  self.emptyLabel.hidden = !isEmpty;
  self.scrollView.hidden = isEmpty;
  self.clearButton.enabled = !isEmpty;
}

- (void)historyDidChange:(NSNotification *)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self loadHistory];
  });
}

#pragma mark - Actions

- (void)clearAllHistory:(id)sender {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"Clear Upload History";
  alert.informativeText = @"Are you sure you want to clear all upload history? This action cannot be undone.";
  [alert addButtonWithTitle:@"Clear All"];
  [alert addButtonWithTitle:@"Cancel"];
  alert.alertStyle = NSAlertStyleWarning;

  [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
    if (returnCode == NSAlertFirstButtonReturn) {
      [[MSTUploadHistoryManager sharedManager] clearAllHistory];
    }
  }];
}

- (void)tableViewDoubleClicked:(id)sender {
  NSInteger row = self.tableView.clickedRow;
  if (row >= 0 && row < (NSInteger)self.historyItems.count) {
    MSTUploadHistoryItem *item = self.historyItems[row];
    [self copyStringToPasteboard:item.url];
    [self showCopiedFeedback];
  }
}

- (void)copyURL:(id)sender {
  NSInteger row = self.tableView.clickedRow;
  if (row >= 0 && row < (NSInteger)self.historyItems.count) {
    MSTUploadHistoryItem *item = self.historyItems[row];
    [self copyStringToPasteboard:item.url];
    [self showCopiedFeedback];
  }
}

- (void)deleteSelectedItem:(id)sender {
  NSInteger row = self.tableView.clickedRow;
  if (row >= 0 && row < (NSInteger)self.historyItems.count) {
    MSTUploadHistoryItem *item = self.historyItems[row];
    [[MSTUploadHistoryManager sharedManager] removeHistoryItem:item];
  }
}

- (void)copyStringToPasteboard:(NSString *)string {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard setString:string forType:NSPasteboardTypeString];
}

- (void)showCopiedFeedback {
  // Brief visual feedback could be added here
}

#pragma mark - Menu Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  NSInteger row = self.tableView.clickedRow;
  if (row < 0 || row >= (NSInteger)self.historyItems.count) {
    return NO;
  }

  return YES;
}

#pragma mark - Hover Preview

- (void)mouseEntered:(NSEvent *)event {
  NSPoint point = [self.tableView convertPoint:event.locationInWindow
                                      fromView:nil];
  NSInteger row = [self.tableView rowAtPoint:point];
  if (row < 0 || row >= (NSInteger)self.historyItems.count) {
    return;
  }
  MSTUploadHistoryItem *item = self.historyItems[row];
  if (!item.thumbnailData) {
    return;
  }
  [self showPreviewForItem:item row:row];
}

- (void)mouseExited:(NSEvent *)event {
  [self hidePreview];
}

- (void)showPreviewForItem:(MSTUploadHistoryItem *)item row:(NSInteger)row {
  [self.previewTask cancel];

  if (!self.previewPopover) {
    self.previewImageView =
        [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 320, 320)];
    self.previewImageView.imageScaling = NSImageScaleProportionallyUpOrDown;

    NSViewController *contentVC = [[NSViewController alloc] init];
    contentVC.view = self.previewImageView;

    self.previewPopover = [[NSPopover alloc] init];
    self.previewPopover.behavior = NSPopoverBehaviorApplicationDefined;
    self.previewPopover.contentViewController = contentVC;
    self.previewPopover.contentSize = NSMakeSize(320, 320);

    self.previewCache = [[NSCache alloc] init];
    self.previewCache.countLimit = 20;
  }

  self.previewRow = row;
  NSImage *cached = item.url ? [self.previewCache objectForKey:item.url] : nil;
  self.previewImageView.image =
      cached ?: [[NSImage alloc] initWithData:item.thumbnailData];

  NSRect cellRect = [self.tableView frameOfCellAtColumn:0 row:row];
  [self.previewPopover showRelativeToRect:cellRect
                                   ofView:self.tableView
                            preferredEdge:NSRectEdgeMaxX];

  // The stored thumbnail is small; fetch the full-size image for a sharp
  // preview and swap it in when it arrives.
  NSURL *url = item.url.length ? [NSURL URLWithString:item.url] : nil;
  if (cached || !url) {
    return;
  }
  __weak typeof(self) weakSelf = self;
  self.previewTask = [[NSURLSession sharedSession]
        dataTaskWithURL:url
      completionHandler:^(NSData *data, NSURLResponse *response,
                          NSError *error) {
        if (!data || error) {
          return;
        }
        NSImage *fullImage = [[NSImage alloc] initWithData:data];
        if (!fullImage) {
          return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          typeof(self) self = weakSelf;
          if (!self) {
            return;
          }
          [self.previewCache setObject:fullImage forKey:item.url];
          if (self.previewRow == row && self.previewPopover.isShown) {
            self.previewImageView.image = fullImage;
          }
        });
      }];
  [self.previewTask resume];
}

- (void)hidePreview {
  [self.previewTask cancel];
  self.previewTask = nil;
  [self.previewPopover close];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return self.historyItems.count;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
  if (row >= (NSInteger)self.historyItems.count) return nil;

  MSTUploadHistoryItem *item = self.historyItems[row];
  NSString *identifier = tableColumn.identifier;

  if ([identifier isEqualToString:@"preview"]) {
    // Preview column - show thumbnail or placeholder
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cellView) {
      cellView = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 40, 36)];
      cellView.identifier = identifier;

      NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 2, 32, 32)];
      imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
      imageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
      cellView.imageView = imageView;
      [cellView addSubview:imageView];

      // Hovering a thumbnail shows an enlarged preview popover
      NSTrackingArea *tracking = [[NSTrackingArea alloc]
          initWithRect:NSZeroRect
               options:(NSTrackingMouseEnteredAndExited |
                        NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect)
                 owner:self
              userInfo:nil];
      [imageView addTrackingArea:tracking];
    }

    if (item.thumbnailData) {
      cellView.imageView.image = [[NSImage alloc] initWithData:item.thumbnailData];
    } else {
      // Show a generic file icon for non-image files
      cellView.imageView.image = [NSImage imageWithSystemSymbolName:@"doc"
                                           accessibilityDescription:@"File"];
      cellView.imageView.contentTintColor = [NSColor secondaryLabelColor];
    }
    return cellView;
  }

  // Text columns - use NSTableCellView for proper vertical centering
  NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
  if (!cellView) {
    cellView = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 36)];
    cellView.identifier = identifier;

    NSTextField *textField = [[NSTextField alloc] initWithFrame:cellView.bounds];
    textField.bezeled = NO;
    textField.drawsBackground = NO;
    textField.editable = NO;
    textField.selectable = YES;
    textField.lineBreakMode = NSLineBreakByTruncatingTail;
    textField.autoresizingMask = NSViewWidthSizable;
    // Center vertically
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    cellView.textField = textField;
    [cellView addSubview:textField];

    [NSLayoutConstraint activateConstraints:@[
      [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:2],
      [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-2],
      [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
    ]];
  }

  NSTextField *textField = cellView.textField;

  if ([identifier isEqualToString:@"filename"]) {
    textField.stringValue = item.filename ?: @"";
    textField.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    textField.textColor = [NSColor labelColor];
  } else if ([identifier isEqualToString:@"url"]) {
    textField.stringValue = item.url ?: @"";
    textField.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    textField.textColor = [NSColor linkColor];
  } else if ([identifier isEqualToString:@"host"]) {
    textField.stringValue = item.hostName ?: @"";
    textField.font = [NSFont systemFontOfSize:11];
    textField.textColor = [NSColor secondaryLabelColor];
  } else if ([identifier isEqualToString:@"date"]) {
    static NSDateFormatter *formatter = nil;
    if (!formatter) {
      formatter = [[NSDateFormatter alloc] init];
      formatter.dateStyle = NSDateFormatterShortStyle;
      formatter.timeStyle = NSDateFormatterShortStyle;
    }
    textField.stringValue = item.uploadDate ? [formatter stringFromDate:item.uploadDate] : @"";
    textField.font = [NSFont systemFontOfSize:11];
    textField.textColor = [NSColor secondaryLabelColor];
  }

  return cellView;
}

@end
