//
//  MSTGeneralViewController.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTGeneralViewController.h"
#import "MSTConfigManager.h"
#import "MSTConstants.h"
#import "MSTiCloudSyncManager.h"
#import "MSTShortLinkService.h"
#import <ServiceManagement/ServiceManagement.h>

@interface MSTGeneralViewController () <NSTextFieldDelegate>

@property(nonatomic, strong) NSButton *launchAtLoginCheckbox;

// Image processing
@property(nonatomic, strong) NSSlider *compressionSlider;
@property(nonatomic, strong) NSTextField *compressionLabel;
@property(nonatomic, strong) NSButton *removeEXIFCheckbox;

// Short links
@property(nonatomic, strong) NSSecureTextField *shortLinkAPIKeyField;
@property(nonatomic, strong) NSButton *shortLinkSaveButton;
@property(nonatomic, strong) NSPopUpButton *shortLinkDomainPopup;
@property(nonatomic, strong) NSButton *shortLinkRefreshButton;
@property(nonatomic, strong) NSTextField *shortLinkStatusLabel;
@property(nonatomic, strong) MSTShortLinkService *shortLinkService;

// iCloud Sync
@property(nonatomic, strong) NSButton *iCloudSyncCheckbox;
@property(nonatomic, strong) NSTextField *lastSyncLabel;

@end

@implementation MSTGeneralViewController

- (instancetype)init {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    self.preferredContentSize = NSMakeSize(500, 560);
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
  self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 560)];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupUI];
  self.shortLinkService = [[MSTShortLinkService alloc] init];
  [self loadSettings];
  [self registerNotifications];
}

- (void)registerNotifications {
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(iCloudDataDidChange:)
             name:MSTiCloudDataDidChangeNotification
           object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(iCloudDataDidChange:)
             name:MSTiCloudSyncDateDidChangeNotification
           object:nil];
}

- (void)setupUI {
  CGFloat padding = 30;
  CGFloat contentWidth = self.view.bounds.size.width - padding * 2;
  CGFloat y = self.view.bounds.size.height - 40;
  CGFloat labelWidth = 180;

  // General section
  NSTextField *generalTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 22)];
  generalTitle.stringValue = @"General";
  generalTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
  generalTitle.textColor = [NSColor labelColor];
  generalTitle.bezeled = NO;
  generalTitle.drawsBackground = NO;
  generalTitle.editable = NO;
  [self.view addSubview:generalTitle];
  y -= 32;

  // Launch at Login checkbox
  self.launchAtLoginCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 18)];
  self.launchAtLoginCheckbox.title = @"Launch Mist at Login";
  [self.launchAtLoginCheckbox setButtonType:NSButtonTypeSwitch];
  self.launchAtLoginCheckbox.target = self;
  self.launchAtLoginCheckbox.action = @selector(launchAtLoginChanged:);
  [self.view addSubview:self.launchAtLoginCheckbox];
  y -= 45;
  
  // iCloud section
  NSTextField *iCloudTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 22)];
  iCloudTitle.stringValue = @"iCloud";
  iCloudTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
  iCloudTitle.textColor = [NSColor labelColor];
  iCloudTitle.bezeled = NO;
  iCloudTitle.drawsBackground = NO;
  iCloudTitle.editable = NO;
  [self.view addSubview:iCloudTitle];
  y -= 32;
  
  // Sync Hosts Configuration checkbox
  self.iCloudSyncCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 18)];
  self.iCloudSyncCheckbox.title = @"Sync Hosts Configuration with iCloud";
  [self.iCloudSyncCheckbox setButtonType:NSButtonTypeSwitch];
  self.iCloudSyncCheckbox.target = self;
  self.iCloudSyncCheckbox.action = @selector(iCloudSyncChanged:);
  [self.view addSubview:self.iCloudSyncCheckbox];
  y -= 26;
  
  // Last sync label
  self.lastSyncLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding + 19, y, contentWidth - 19, 14)];
  self.lastSyncLabel.font = [NSFont systemFontOfSize:11];
  self.lastSyncLabel.textColor = [NSColor tertiaryLabelColor];
  self.lastSyncLabel.bezeled = NO;
  self.lastSyncLabel.drawsBackground = NO;
  self.lastSyncLabel.editable = NO;
  self.lastSyncLabel.selectable = NO;
  [self.view addSubview:self.lastSyncLabel];
  y -= 40;

  // Short Links section
  NSTextField *shortLinkTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 22)];
  shortLinkTitle.stringValue = @"Short Links (s.ee)";
  shortLinkTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
  shortLinkTitle.textColor = [NSColor labelColor];
  shortLinkTitle.bezeled = NO;
  shortLinkTitle.drawsBackground = NO;
  shortLinkTitle.editable = NO;
  [self.view addSubview:shortLinkTitle];
  y -= 32;

  NSTextField *apiKeyLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding, y, labelWidth, 18)];
  apiKeyLabel.stringValue = @"API Key";
  apiKeyLabel.font = [NSFont systemFontOfSize:13];
  apiKeyLabel.textColor = [NSColor labelColor];
  apiKeyLabel.bezeled = NO;
  apiKeyLabel.drawsBackground = NO;
  apiKeyLabel.editable = NO;
  [self.view addSubview:apiKeyLabel];

  CGFloat apiFieldWidth = contentWidth - labelWidth - 110;
  self.shortLinkAPIKeyField = [[NSSecureTextField alloc]
      initWithFrame:NSMakeRect(padding + labelWidth + 10, y, apiFieldWidth, 22)];
  self.shortLinkAPIKeyField.placeholderString = @"Enter s.ee API Key";
  self.shortLinkAPIKeyField.target = self;
  self.shortLinkAPIKeyField.action = @selector(shortLinkAPIKeyChanged:);
  self.shortLinkAPIKeyField.delegate = self;
  [self.view addSubview:self.shortLinkAPIKeyField];

  self.shortLinkSaveButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(padding + labelWidth + 10 + apiFieldWidth + 6, y - 1, 80, 24)];
  self.shortLinkSaveButton.title = @"Save";
  self.shortLinkSaveButton.bezelStyle = NSBezelStyleRounded;
  self.shortLinkSaveButton.target = self;
  self.shortLinkSaveButton.action = @selector(shortLinkSave:);
  [self.view addSubview:self.shortLinkSaveButton];
  y -= 30;

  NSTextField *domainLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding, y + 2, labelWidth, 18)];
  domainLabel.stringValue = @"Default Domain";
  domainLabel.font = [NSFont systemFontOfSize:13];
  domainLabel.textColor = [NSColor labelColor];
  domainLabel.bezeled = NO;
  domainLabel.drawsBackground = NO;
  domainLabel.editable = NO;
  [self.view addSubview:domainLabel];

  self.shortLinkDomainPopup = [[NSPopUpButton alloc]
      initWithFrame:NSMakeRect(padding + labelWidth + 10, y, contentWidth - labelWidth - 110, 26)];
  self.shortLinkDomainPopup.target = self;
  self.shortLinkDomainPopup.action = @selector(shortLinkDomainChanged:);
  [self.view addSubview:self.shortLinkDomainPopup];

  self.shortLinkRefreshButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(padding + contentWidth - 90, y, 90, 26)];
  self.shortLinkRefreshButton.title = @"Refresh";
  self.shortLinkRefreshButton.bezelStyle = NSBezelStyleRounded;
  self.shortLinkRefreshButton.target = self;
  self.shortLinkRefreshButton.action = @selector(refreshShortLinkDomains:);
  [self.view addSubview:self.shortLinkRefreshButton];
  y -= 24;

  self.shortLinkStatusLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding + labelWidth + 10, y, contentWidth - labelWidth - 20, 16)];
  self.shortLinkStatusLabel.font = [NSFont systemFontOfSize:11];
  self.shortLinkStatusLabel.textColor = [NSColor tertiaryLabelColor];
  self.shortLinkStatusLabel.bezeled = NO;
  self.shortLinkStatusLabel.drawsBackground = NO;
  self.shortLinkStatusLabel.editable = NO;
  self.shortLinkStatusLabel.selectable = NO;
  [self.view addSubview:self.shortLinkStatusLabel];
  y -= 24;
  
  // Image Processing section
  NSTextField *imageTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 22)];
  imageTitle.stringValue = @"Image Processing";
  imageTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
  imageTitle.textColor = [NSColor labelColor];
  imageTitle.bezeled = NO;
  imageTitle.drawsBackground = NO;
  imageTitle.editable = NO;
  [self.view addSubview:imageTitle];
  y -= 35;
  
  // Compression quality label and value
  NSTextField *compressionTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, labelWidth, 18)];
  compressionTitle.stringValue = @"Compression Quality";
  compressionTitle.font = [NSFont systemFontOfSize:13];
  compressionTitle.textColor = [NSColor labelColor];
  compressionTitle.bezeled = NO;
  compressionTitle.drawsBackground = NO;
  compressionTitle.editable = NO;
  [self.view addSubview:compressionTitle];
  
  self.compressionLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding + contentWidth - 60, y, 60, 18)];
  self.compressionLabel.font = [NSFont systemFontOfSize:12];
  self.compressionLabel.textColor = [NSColor secondaryLabelColor];
  self.compressionLabel.bezeled = NO;
  self.compressionLabel.drawsBackground = NO;
  self.compressionLabel.editable = NO;
  self.compressionLabel.alignment = NSTextAlignmentRight;
  [self.view addSubview:self.compressionLabel];
  y -= 28;
  
  // Compression slider
  self.compressionSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 24)];
  self.compressionSlider.minValue = 0;
  self.compressionSlider.maxValue = 90;
  self.compressionSlider.numberOfTickMarks = 10;
  self.compressionSlider.allowsTickMarkValuesOnly = YES;
  self.compressionSlider.target = self;
  self.compressionSlider.action = @selector(compressionChanged:);
  [self.view addSubview:self.compressionSlider];
  y -= 40;
  
  // Remove EXIF checkbox
  self.removeEXIFCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 18)];
  self.removeEXIFCheckbox.title = @"Remove EXIF metadata from images";
  [self.removeEXIFCheckbox setButtonType:NSButtonTypeSwitch];
  self.removeEXIFCheckbox.target = self;
  self.removeEXIFCheckbox.action = @selector(removeEXIFChanged:);
  [self.view addSubview:self.removeEXIFCheckbox];
  y -= 45;
  
  // Help text
  NSTextField *helpLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding, y, contentWidth, 42)];
  helpLabel.stringValue = @"Compression quality: 0 = disabled, 10-90 = quality level. "
                          @"EXIF metadata contains location and camera information.";
  helpLabel.font = [NSFont systemFontOfSize:11];
  helpLabel.textColor = [NSColor tertiaryLabelColor];
  helpLabel.bezeled = NO;
  helpLabel.drawsBackground = NO;
  helpLabel.editable = NO;
  helpLabel.lineBreakMode = NSLineBreakByWordWrapping;
  helpLabel.maximumNumberOfLines = 3;
  [self.view addSubview:helpLabel];
}

- (void)loadSettings {
  // Load launch at login status
  if (@available(macOS 13.0, *)) {
    SMAppService *service = [SMAppService mainAppService];
    self.launchAtLoginCheckbox.state =
        (service.status == SMAppServiceStatusEnabled) ? NSControlStateValueOn
                                                      : NSControlStateValueOff;
  } else {
    self.launchAtLoginCheckbox.enabled = NO;
    self.launchAtLoginCheckbox.title = @"Launch at Login (requires macOS 13+)";
  }
  
  // Load image processing settings
  NSInteger compressionFactor = [MSTConfigManager sharedManager].compressFactor;
  self.compressionSlider.integerValue = compressionFactor;
  [self updateCompressionLabel];
  
  BOOL removeEXIF = [MSTConfigManager sharedManager].removeEXIF;
  self.removeEXIFCheckbox.state = removeEXIF ? NSControlStateValueOn : NSControlStateValueOff;
  
  // Load iCloud sync settings
  BOOL iCloudAvailable = [MSTConfigManager sharedManager].iCloudAvailable;
  BOOL iCloudSyncEnabled = [MSTConfigManager sharedManager].iCloudSyncEnabled;
  
  self.iCloudSyncCheckbox.state = iCloudSyncEnabled ? NSControlStateValueOn : NSControlStateValueOff;
  self.iCloudSyncCheckbox.enabled = iCloudAvailable;
  
  if (!iCloudAvailable) {
    self.iCloudSyncCheckbox.title = @"Sync Hosts Configuration with iCloud (iCloud not available)";
  }
  
  [self updateLastSyncLabel];

  // Short links
  MSTConfigManager *manager = [MSTConfigManager sharedManager];
  self.shortLinkAPIKeyField.stringValue = manager.shortLinkAPIKey ?: @"";
  self.shortLinkSaveButton.enabled = self.shortLinkAPIKeyField.stringValue.length > 0;
  [self reloadShortLinkDomains];
  [self updateShortLinkControlsEnabled];
}

- (void)launchAtLoginChanged:(NSButton *)sender {
  if (@available(macOS 13.0, *)) {
    SMAppService *service = [SMAppService mainAppService];
    NSError *error = nil;

    if (sender.state == NSControlStateValueOn) {
      [service registerAndReturnError:&error];
    } else {
      [service unregisterAndReturnError:&error];
    }

    if (error) {
      NSLog(@"Launch at login error: %@", error.localizedDescription);
      // Revert checkbox state on error
      sender.state = (service.status == SMAppServiceStatusEnabled)
                         ? NSControlStateValueOn
                         : NSControlStateValueOff;
    }
  }
}

- (void)compressionChanged:(NSSlider *)sender {
  NSInteger value = sender.integerValue;
  [MSTConfigManager sharedManager].compressFactor = value;
  [[MSTConfigManager sharedManager] saveConfigs];
  [self updateCompressionLabel];
}

- (void)updateCompressionLabel {
  NSInteger value = self.compressionSlider.integerValue;
  if (value == 0) {
    self.compressionLabel.stringValue = @"Off";
  } else {
    self.compressionLabel.stringValue = [NSString stringWithFormat:@"%ld%%", (long)value];
  }
}

- (void)shortLinkAPIKeyChanged:(id)sender {
  self.shortLinkSaveButton.enabled = self.shortLinkAPIKeyField.stringValue.length > 0;
}

- (void)shortLinkSave:(id)sender {
  NSString *apiKey = [self.shortLinkAPIKeyField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  MSTConfigManager *manager = [MSTConfigManager sharedManager];
  manager.shortLinkAPIKey = apiKey ?: @"";
  [manager saveConfigs];
  [self updateShortLinkControlsEnabled];
  if (manager.shortLinkAPIKey.length > 0) {
    [self refreshShortLinkDomains:nil];
  } else {
    self.shortLinkStatusLabel.stringValue = @"Enter API key to load domains.";
  }
}

- (void)refreshShortLinkDomains:(id)sender {
  MSTConfigManager *manager = [MSTConfigManager sharedManager];
  NSString *apiKey = manager.shortLinkAPIKey.length > 0 ? manager.shortLinkAPIKey : self.shortLinkAPIKeyField.stringValue;
  if (apiKey.length == 0) {
    self.shortLinkStatusLabel.stringValue = @"API key required to fetch domains.";
    self.shortLinkStatusLabel.textColor = [NSColor systemOrangeColor];
    return;
  }

  self.shortLinkRefreshButton.enabled = NO;
  self.shortLinkStatusLabel.stringValue = @"Refreshing domains...";
  self.shortLinkStatusLabel.textColor = [NSColor tertiaryLabelColor];

  [self.shortLinkService fetchAvailableDomainsWithAPIKey:apiKey
                                              completion:^(NSArray<NSString *> *domains, NSError *error) {
                                                self.shortLinkRefreshButton.enabled = YES;
                                                if (error || domains.count == 0) {
                                                  self.shortLinkStatusLabel.stringValue = error.localizedDescription ?: @"No domains returned";
                                                  self.shortLinkStatusLabel.textColor = [NSColor systemRedColor];
                                                  [self updateShortLinkControlsEnabled];
                                                  return;
                                                }

                                                manager.shortLinkAPIKey = apiKey;
                                                manager.shortLinkDomains = domains;
                                                if (manager.shortLinkDefaultDomain.length == 0 || ![domains containsObject:manager.shortLinkDefaultDomain]) {
                                                  manager.shortLinkDefaultDomain = domains.firstObject ?: @"s.ee";
                                                }
                                                [manager saveConfigs];
                                                [self reloadShortLinkDomains];
                                                self.shortLinkStatusLabel.stringValue = @"Domains updated";
                                                self.shortLinkStatusLabel.textColor = [NSColor tertiaryLabelColor];
                                                [self updateShortLinkControlsEnabled];
                                              }];
}

- (void)shortLinkDomainChanged:(id)sender {
  NSString *selected = self.shortLinkDomainPopup.selectedItem.title ?: @"";
  MSTConfigManager *manager = [MSTConfigManager sharedManager];
  manager.shortLinkDefaultDomain = selected;
  [manager saveConfigs];
}

- (void)reloadShortLinkDomains {
  MSTConfigManager *manager = [MSTConfigManager sharedManager];
  NSMutableOrderedSet *domainsSet = [[NSMutableOrderedSet alloc] init];
  if (manager.shortLinkDefaultDomain.length > 0) {
    [domainsSet addObject:manager.shortLinkDefaultDomain];
  }
  for (NSString *d in manager.shortLinkDomains) {
    if ([d isKindOfClass:[NSString class]] && d.length > 0) {
      [domainsSet addObject:d];
    }
  }
  if (domainsSet.count == 0) {
    [domainsSet addObject:@"s.ee"];
  }

  [self.shortLinkDomainPopup removeAllItems];
  for (NSString *d in domainsSet) {
    [self.shortLinkDomainPopup addItemWithTitle:d];
  }

  NSString *current = manager.shortLinkDefaultDomain.length > 0 ? manager.shortLinkDefaultDomain : domainsSet.firstObject;
  [self.shortLinkDomainPopup selectItemWithTitle:current];
}

- (void)updateShortLinkControlsEnabled {
  BOOL hasKey = ([self.shortLinkAPIKeyField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) || [MSTConfigManager sharedManager].shortLinkAPIKey.length > 0;
  self.shortLinkDomainPopup.enabled = hasKey;
  self.shortLinkRefreshButton.enabled = hasKey;
  self.shortLinkSaveButton.enabled = hasKey;
  if (hasKey) {
    self.shortLinkStatusLabel.textColor = [NSColor tertiaryLabelColor];
    if (self.shortLinkDomainPopup.numberOfItems == 0) {
      self.shortLinkStatusLabel.stringValue = @"Click Refresh to load domains.";
    } else {
      self.shortLinkStatusLabel.stringValue = @"Default domain for creating short links.";
    }
  } else {
    self.shortLinkStatusLabel.textColor = [NSColor systemOrangeColor];
    self.shortLinkStatusLabel.stringValue = @"Enter API key to enable s.ee short links.";
  }
}

- (void)controlTextDidChange:(NSNotification *)notification {
  if (notification.object == self.shortLinkAPIKeyField) {
    BOOL hasText = [[self.shortLinkAPIKeyField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
    self.shortLinkSaveButton.enabled = hasText;
    [self updateShortLinkControlsEnabled];
  }
}

- (void)removeEXIFChanged:(NSButton *)sender {
  BOOL enabled = (sender.state == NSControlStateValueOn);
  [MSTConfigManager sharedManager].removeEXIF = enabled;
  [[MSTConfigManager sharedManager] saveConfigs];
}

- (void)iCloudSyncChanged:(NSButton *)sender {
  BOOL enabled = (sender.state == NSControlStateValueOn);
  [MSTConfigManager sharedManager].iCloudSyncEnabled = enabled;
  [self updateLastSyncLabel];
  
  if (enabled) {
    NSLog(@"[iCloud Sync] User enabled iCloud sync");
  }
}

- (void)updateLastSyncLabel {
  MSTConfigManager *manager = [MSTConfigManager sharedManager];
  
  if (!manager.iCloudAvailable) {
    self.lastSyncLabel.stringValue = @"iCloud is not available. Please sign in to iCloud in System Settings.";
    self.lastSyncLabel.textColor = [NSColor systemOrangeColor];
    return;
  }
  
  if (!manager.iCloudSyncEnabled) {
    self.lastSyncLabel.stringValue = @"";
    return;
  }
  
  NSDate *lastSync = manager.iCloudSyncManager.lastSyncDate;
  if (lastSync) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    formatter.doesRelativeDateFormatting = YES;
    
    NSString *dateString = [formatter stringFromDate:lastSync];
    self.lastSyncLabel.stringValue = [NSString stringWithFormat:@"Last synced: %@", dateString];
    self.lastSyncLabel.textColor = [NSColor secondaryLabelColor];
  } else {
    self.lastSyncLabel.stringValue = @"Waiting for first sync...";
    self.lastSyncLabel.textColor = [NSColor secondaryLabelColor];
  }
}

- (void)iCloudDataDidChange:(NSNotification *)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self updateLastSyncLabel];
  });
}

@end
