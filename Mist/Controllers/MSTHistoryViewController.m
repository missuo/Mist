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

@end

@implementation MSTHistoryViewController

- (instancetype)init {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    self.preferredContentSize = NSMakeSize(600, 400);
  }
  return self;
}

- (void)loadView {
  self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 600, 400)];
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
  // Clear button
  self.clearButton = [[NSButton alloc] initWithFrame:NSMakeRect(490, 365, 90, 24)];
  self.clearButton.title = @"Clear All";
  self.clearButton.bezelStyle = NSBezelStyleRounded;
  self.clearButton.target = self;
  self.clearButton.action = @selector(clearAllHistory:);
  self.clearButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  [self.view addSubview:self.clearButton];

  // Table view in scroll view
  self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 20, 560, 335)];
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
  filenameColumn.width = 140;
  filenameColumn.minWidth = 80;
  [self.tableView addTableColumn:filenameColumn];

  // URL column
  NSTableColumn *urlColumn = [[NSTableColumn alloc] initWithIdentifier:@"url"];
  urlColumn.title = @"URL";
  urlColumn.width = 180;
  urlColumn.minWidth = 100;
  [self.tableView addTableColumn:urlColumn];

  // Host column
  NSTableColumn *hostColumn = [[NSTableColumn alloc] initWithIdentifier:@"host"];
  hostColumn.title = @"Host";
  hostColumn.width = 80;
  hostColumn.minWidth = 60;
  [self.tableView addTableColumn:hostColumn];

  // Date column
  NSTableColumn *dateColumn = [[NSTableColumn alloc] initWithIdentifier:@"date"];
  dateColumn.title = @"Date";
  dateColumn.width = 100;
  dateColumn.minWidth = 80;
  [self.tableView addTableColumn:dateColumn];

  self.scrollView.documentView = self.tableView;
  [self.view addSubview:self.scrollView];

  // Empty state label
  self.emptyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 180, 600, 40)];
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
  [contextMenu addItemWithTitle:@"Copy Short URL" action:@selector(copyShortURL:) keyEquivalent:@""];
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
    NSString *urlToCopy = item.shortURL ?: item.url;
    [self copyStringToPasteboard:urlToCopy];
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

- (void)copyShortURL:(id)sender {
  NSInteger row = self.tableView.clickedRow;
  if (row >= 0 && row < (NSInteger)self.historyItems.count) {
    MSTUploadHistoryItem *item = self.historyItems[row];
    NSString *urlToCopy = item.shortURL ?: item.url;
    [self copyStringToPasteboard:urlToCopy];
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

  if (menuItem.action == @selector(copyShortURL:)) {
    MSTUploadHistoryItem *item = self.historyItems[row];
    return item.shortURL.length > 0 || item.url.length > 0;
  }

  return YES;
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
    textField.stringValue = item.shortURL ?: item.url ?: @"";
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
