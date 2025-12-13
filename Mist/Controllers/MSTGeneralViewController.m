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
#import <ServiceManagement/ServiceManagement.h>

@interface MSTGeneralViewController ()

@property(nonatomic, strong) NSButton *launchAtLoginCheckbox;

// Image processing
@property(nonatomic, strong) NSSlider *compressionSlider;
@property(nonatomic, strong) NSTextField *compressionLabel;
@property(nonatomic, strong) NSButton *removeEXIFCheckbox;

// iCloud Sync
@property(nonatomic, strong) NSButton *iCloudSyncCheckbox;
@property(nonatomic, strong) NSTextField *lastSyncLabel;

@end

@implementation MSTGeneralViewController

- (instancetype)init {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    self.preferredContentSize = NSMakeSize(500, 380);
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
  self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 380)];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupUI];
  [self loadSettings];
  [self registerNotifications];
}

- (void)registerNotifications {
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(iCloudDataDidChange:)
             name:MSTiCloudDataDidChangeNotification
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
  y -= 35;

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
