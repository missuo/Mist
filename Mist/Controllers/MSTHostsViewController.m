//
//  MSTHostsViewController.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTHostsViewController.h"
#import "MSTConfigManager.h"
#import "MSTConstants.h"
#import "MSTS3ConfigViewController.h"
#import "MSTS3HostConfig.h"
#import "MSTS3Region.h"

@interface MSTHostsViewController () <NSTableViewDelegate,
                                      NSTableViewDataSource>

@property(nonatomic, strong) NSSplitView *splitView;
@property(nonatomic, strong) NSTableView *tableView;
@property(nonatomic, strong) NSScrollView *tableScrollView;
@property(nonatomic, strong) NSView *detailContainer;
@property(nonatomic, strong) MSTS3ConfigViewController *configVC;
@property(nonatomic, strong) NSButton *addButton;
@property(nonatomic, strong) NSButton *removeButton;
@property(nonatomic, strong) NSButton *duplicateButton;
@property(nonatomic, strong) NSButton *defaultButton;

@end

@implementation MSTHostsViewController

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
  [self registerNotifications];
}

- (void)setupUI {
  CGFloat sidebarWidth = 200;
  CGFloat toolbarHeight = 32;
  CGFloat viewHeight = self.view.bounds.size.height;
  CGFloat viewWidth = self.view.bounds.size.width;

  // Left panel - host list
  NSView *leftPanel =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, sidebarWidth, viewHeight)];
  leftPanel.autoresizingMask = NSViewHeightSizable;

  // Table view
  self.tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.headerView = nil;
  self.tableView.rowHeight = 44;
  self.tableView.selectionHighlightStyle =
      NSTableViewSelectionHighlightStyleRegular;
  self.tableView.intercellSpacing = NSMakeSize(0, 1);

  NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"host"];
  column.width = sidebarWidth - 20;
  [self.tableView addTableColumn:column];

  self.tableScrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, toolbarHeight, sidebarWidth,
                               viewHeight - toolbarHeight)];
  self.tableScrollView.documentView = self.tableView;
  self.tableScrollView.hasVerticalScroller = YES;
  self.tableScrollView.autoresizingMask =
      NSViewWidthSizable | NSViewHeightSizable;
  self.tableScrollView.borderType = NSNoBorder;
  [leftPanel addSubview:self.tableScrollView];

  // Bottom toolbar
  NSView *toolbar = [[NSView alloc]
      initWithFrame:NSMakeRect(0, 0, sidebarWidth, toolbarHeight)];
  toolbar.autoresizingMask = NSViewWidthSizable;

  // Separator line at top
  NSBox *separator = [[NSBox alloc]
      initWithFrame:NSMakeRect(0, toolbarHeight - 1, sidebarWidth, 1)];
  separator.boxType = NSBoxSeparator;
  separator.autoresizingMask = NSViewWidthSizable;
  [toolbar addSubview:separator];

  self.addButton =
      [self createToolbarButtonWithSymbol:@"plus"
                                  tooltip:@"Add Host"
                                    frame:NSMakeRect(4, 2, 28, 28)];
  self.addButton.action = @selector(addHost:);
  [toolbar addSubview:self.addButton];

  self.removeButton =
      [self createToolbarButtonWithSymbol:@"minus"
                                  tooltip:@"Remove Host"
                                    frame:NSMakeRect(32, 2, 28, 28)];
  self.removeButton.action = @selector(removeHost:);
  [toolbar addSubview:self.removeButton];

  self.duplicateButton =
      [self createToolbarButtonWithSymbol:@"doc.on.doc"
                                  tooltip:@"Duplicate Host"
                                    frame:NSMakeRect(60, 2, 28, 28)];
  self.duplicateButton.action = @selector(copyHost:);
  [toolbar addSubview:self.duplicateButton];

  self.defaultButton =
      [self createToolbarButtonWithSymbol:@"star"
                                  tooltip:@"Set as Default"
                                    frame:NSMakeRect(88, 2, 28, 28)];
  self.defaultButton.action = @selector(setDefaultHost:);
  [toolbar addSubview:self.defaultButton];

  [leftPanel addSubview:toolbar];

  // Vertical separator
  NSBox *vertSeparator =
      [[NSBox alloc] initWithFrame:NSMakeRect(sidebarWidth, 0, 1, viewHeight)];
  vertSeparator.boxType = NSBoxSeparator;
  vertSeparator.autoresizingMask = NSViewHeightSizable;
  [self.view addSubview:vertSeparator];

  // Right panel - config editor
  CGFloat detailWidth = viewWidth - sidebarWidth - 1;
  self.detailContainer = [[NSView alloc]
      initWithFrame:NSMakeRect(sidebarWidth + 1, 0, detailWidth, viewHeight)];
  self.detailContainer.autoresizingMask =
      NSViewWidthSizable | NSViewHeightSizable;

  [self.view addSubview:leftPanel];
  [self.view addSubview:self.detailContainer];

  // Config view controller
  self.configVC = [[MSTS3ConfigViewController alloc] init];
  self.configVC.view.frame = self.detailContainer.bounds;
  self.configVC.view.autoresizingMask =
      NSViewWidthSizable | NSViewHeightSizable;
  [self.detailContainer addSubview:self.configVC.view];
  [self addChildViewController:self.configVC];

  [self updateButtonStates];
}

- (NSButton *)createToolbarButtonWithSymbol:(NSString *)symbol
                                    tooltip:(NSString *)tooltip
                                      frame:(NSRect)frame {
  NSButton *button = [[NSButton alloc] initWithFrame:frame];
  button.bezelStyle = NSBezelStyleSmallSquare;
  button.bordered = NO;
  button.image = [NSImage imageWithSystemSymbolName:symbol
                           accessibilityDescription:tooltip];
  button.target = self;
  button.toolTip = tooltip;
  return button;
}

- (void)registerNotifications {
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(configDidChange:)
             name:MSTConfigDidChangeNotification
           object:nil];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)configDidChange:(NSNotification *)notification {
  [self.tableView reloadData];
  [self updateButtonStates];
}

#pragma mark - Actions

- (void)addHost:(id)sender {
  MSTS3HostConfig *newHost = [[MSTS3HostConfig alloc] init];
  [[MSTConfigManager sharedManager] addHostConfig:newHost];
  [self.tableView reloadData];

  // Select the new host
  NSInteger row = [MSTConfigManager sharedManager].hostConfigs.count - 1;
  [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
              byExtendingSelection:NO];
  [self tableViewSelectionDidChange:
            [NSNotification
                notificationWithName:NSTableViewSelectionDidChangeNotification
                              object:self.tableView]];
}

- (void)removeHost:(id)sender {
  NSInteger row = self.tableView.selectedRow;
  if (row < 0)
    return;

  NSArray *configs = [MSTConfigManager sharedManager].hostConfigs;
  if (row >= configs.count)
    return;

  MSTS3HostConfig *config = configs[row];
  [[MSTConfigManager sharedManager] removeHostConfig:config];
  [self.tableView reloadData];

  // Select previous row or first
  if (configs.count > 1) {
    NSInteger newRow = row > 0 ? row - 1 : 0;
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow]
                byExtendingSelection:NO];
  }
  [self updateButtonStates];
}

- (void)copyHost:(id)sender {
  NSInteger row = self.tableView.selectedRow;
  if (row < 0)
    return;

  NSArray *configs = [MSTConfigManager sharedManager].hostConfigs;
  if (row >= configs.count)
    return;

  MSTS3HostConfig *config = configs[row];
  MSTS3HostConfig *copiedConfig = [config copyWithNewIdentifier];
  [[MSTConfigManager sharedManager] addHostConfig:copiedConfig];
  [self.tableView reloadData];

  // Select the new copied host
  NSInteger newRow = [MSTConfigManager sharedManager].hostConfigs.count - 1;
  [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow]
              byExtendingSelection:NO];
  [self tableViewSelectionDidChange:
            [NSNotification
                notificationWithName:NSTableViewSelectionDidChangeNotification
                              object:self.tableView]];
}

- (void)setDefaultHost:(id)sender {
  NSInteger row = self.tableView.selectedRow;
  if (row < 0)
    return;

  NSArray *configs = [MSTConfigManager sharedManager].hostConfigs;
  if (row >= configs.count)
    return;

  MSTS3HostConfig *config = configs[row];
  [[MSTConfigManager sharedManager]
      setDefaultHostWithIdentifier:config.identifier];
  [self.tableView reloadData];
}

- (void)updateButtonStates {
  NSInteger row = self.tableView.selectedRow;
  BOOL hasSelection = row >= 0;
  BOOL isDefault = NO;

  if (hasSelection) {
    NSArray *configs = [MSTConfigManager sharedManager].hostConfigs;
    if (row < configs.count) {
      MSTS3HostConfig *config = configs[row];
      isDefault = config.isDefault;
    }
  }

  self.removeButton.enabled = hasSelection;
  self.duplicateButton.enabled = hasSelection;
  self.defaultButton.enabled = hasSelection && !isDefault;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return [MSTConfigManager sharedManager].hostConfigs.count;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
  NSArray *configs = [MSTConfigManager sharedManager].hostConfigs;
  if (row >= configs.count)
    return nil;

  MSTS3HostConfig *config = configs[row];

  NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"HostCell"
                                                          owner:self];
  if (!cellView) {
    cellView =
        [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 180, 44)];
    cellView.identifier = @"HostCell";

    // Provider icon
    NSImageView *iconView =
        [[NSImageView alloc] initWithFrame:NSMakeRect(8, 10, 24, 24)];
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    iconView.tag = 3;
    [cellView addSubview:iconView];
    cellView.imageView = iconView;

    NSTextField *nameField =
        [[NSTextField alloc] initWithFrame:NSMakeRect(40, 22, 138, 18)];
    nameField.bezeled = NO;
    nameField.drawsBackground = NO;
    nameField.editable = NO;
    nameField.selectable = NO;
    nameField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    nameField.lineBreakMode = NSLineBreakByTruncatingTail;
    nameField.tag = 1;
    [cellView addSubview:nameField];
    cellView.textField = nameField;

    NSTextField *bucketField =
        [[NSTextField alloc] initWithFrame:NSMakeRect(40, 4, 138, 16)];
    bucketField.bezeled = NO;
    bucketField.drawsBackground = NO;
    bucketField.editable = NO;
    bucketField.selectable = NO;
    bucketField.font = [NSFont systemFontOfSize:11];
    bucketField.textColor = [NSColor secondaryLabelColor];
    bucketField.lineBreakMode = NSLineBreakByTruncatingTail;
    bucketField.tag = 2;
    [cellView addSubview:bucketField];
  }

  NSImageView *iconView = [cellView viewWithTag:3];
  NSTextField *nameField = [cellView viewWithTag:1];
  NSTextField *bucketField = [cellView viewWithTag:2];

  // Set provider icon
  NSString *iconName = [self iconNameForProviderType:config.providerType];
  iconView.image = [NSImage imageNamed:iconName];

  NSString *name = config.name;
  if (config.isDefault) {
    name = [name stringByAppendingString:@" ★"];
  }
  nameField.stringValue = name;
  if (config.providerType == MSTS3ProviderTypeSMMS) {
    bucketField.stringValue = @"SM.MS";
  } else {
    bucketField.stringValue =
        config.bucket.length > 0 ? config.bucket : @"(not configured)";
  }

  return cellView;
}

- (NSString *)iconNameForProviderType:(MSTS3ProviderType)providerType {
  switch (providerType) {
  case MSTS3ProviderTypeAmazonS3:
    return @"aws";
  case MSTS3ProviderTypeWasabi:
    return @"wasabi";
  case MSTS3ProviderTypeCloudflareR2:
    return @"cloudflare";
  case MSTS3ProviderTypeBackblazeB2:
    return @"backblaze";
  case MSTS3ProviderTypeMinIO:
    return @"minio";
  case MSTS3ProviderTypeSMMS:
    return @"sm.ms";
  case MSTS3ProviderTypeCustom:
  default:
    return @"custom";
  }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  NSInteger row = self.tableView.selectedRow;
  [self updateButtonStates];

  if (row >= 0) {
    NSArray *configs = [MSTConfigManager sharedManager].hostConfigs;
    if (row < configs.count) {
      [self.configVC setConfig:configs[row]];
    }
  } else {
    [self.configVC setConfig:nil];
  }
}

@end
