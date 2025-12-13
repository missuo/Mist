//
//  MSTGeneralViewController.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTGeneralViewController.h"
#import "MSTConfigManager.h"
#import "MSTConstants.h"
#import <ServiceManagement/ServiceManagement.h>

@interface MSTGeneralViewController ()

@property(nonatomic, strong) NSSegmentedControl *outputFormatControl;
@property(nonatomic, strong) NSTextField *previewLabel;
@property(nonatomic, strong) NSButton *launchAtLoginCheckbox;

// Image processing
@property(nonatomic, strong) NSSlider *compressionSlider;
@property(nonatomic, strong) NSTextField *compressionLabel;
@property(nonatomic, strong) NSButton *removeEXIFCheckbox;

@end

@implementation MSTGeneralViewController

- (instancetype)init {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    self.preferredContentSize = NSMakeSize(450, 450);
  }
  return self;
}

- (void)loadView {
  self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 450, 450)];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupUI];
  [self loadSettings];
}

- (void)setupUI {
  CGFloat padding = 20;
  CGFloat contentWidth = self.view.bounds.size.width - padding * 2;
  CGFloat y = self.view.bounds.size.height - 30;

  // Section title
  NSTextField *sectionTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, 200, 20)];
  sectionTitle.stringValue = @"Output Format";
  sectionTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  sectionTitle.textColor = [NSColor labelColor];
  sectionTitle.bezeled = NO;
  sectionTitle.drawsBackground = NO;
  sectionTitle.editable = NO;
  [self.view addSubview:sectionTitle];
  y -= 40;

  // Segmented control with 4 options
  self.outputFormatControl = [[NSSegmentedControl alloc]
      initWithFrame:NSMakeRect(padding, y, contentWidth, 28)];
  self.outputFormatControl.segmentCount = 4;
  [self.outputFormatControl setLabel:@"URL" forSegment:0];
  [self.outputFormatControl setLabel:@"Markdown" forSegment:1];
  [self.outputFormatControl setLabel:@"HTML" forSegment:2];
  [self.outputFormatControl setLabel:@"UBB" forSegment:3];
  self.outputFormatControl.segmentStyle = NSSegmentStyleRounded;
  self.outputFormatControl.target = self;
  self.outputFormatControl.action = @selector(outputFormatChanged:);
  [self.view addSubview:self.outputFormatControl];
  y -= 35;

  // Preview title
  NSTextField *previewTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, 100, 16)];
  previewTitle.stringValue = @"Preview:";
  previewTitle.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
  previewTitle.textColor = [NSColor secondaryLabelColor];
  previewTitle.bezeled = NO;
  previewTitle.drawsBackground = NO;
  previewTitle.editable = NO;
  [self.view addSubview:previewTitle];
  y -= 28;

  // Preview label with monospace font
  self.previewLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding, y, contentWidth, 22)];
  self.previewLabel.font =
      [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
  self.previewLabel.textColor = [NSColor labelColor];
  self.previewLabel.backgroundColor = [NSColor quaternarySystemFillColor];
  self.previewLabel.bezeled = NO;
  self.previewLabel.drawsBackground = YES;
  self.previewLabel.editable = NO;
  self.previewLabel.selectable = YES;
  self.previewLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
  self.previewLabel.wantsLayer = YES;
  self.previewLabel.layer.cornerRadius = 4;
  [self.view addSubview:self.previewLabel];
  y -= 35;

  // Footer hint
  NSTextField *hintLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding, y, contentWidth, 32)];
  hintLabel.stringValue = @"The selected format will be used when copying "
                          @"upload URLs to clipboard.";
  hintLabel.font = [NSFont systemFontOfSize:11];
  hintLabel.textColor = [NSColor tertiaryLabelColor];
  hintLabel.bezeled = NO;
  hintLabel.drawsBackground = NO;
  hintLabel.editable = NO;
  [self.view addSubview:hintLabel];
  y -= 40;

  // Startup section
  NSTextField *startupTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, 200, 20)];
  startupTitle.stringValue = @"Startup";
  startupTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  startupTitle.textColor = [NSColor labelColor];
  startupTitle.bezeled = NO;
  startupTitle.drawsBackground = NO;
  startupTitle.editable = NO;
  [self.view addSubview:startupTitle];
  y -= 30;

  // Launch at Login checkbox
  self.launchAtLoginCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 20)];
  self.launchAtLoginCheckbox.title = @"Launch Mist at Login";
  [self.launchAtLoginCheckbox setButtonType:NSButtonTypeSwitch];
  self.launchAtLoginCheckbox.target = self;
  self.launchAtLoginCheckbox.action = @selector(launchAtLoginChanged:);
  [self.view addSubview:self.launchAtLoginCheckbox];
  y -= 40;
  
  // Image Processing section
  NSTextField *imageTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, 200, 20)];
  imageTitle.stringValue = @"Image Processing";
  imageTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  imageTitle.textColor = [NSColor labelColor];
  imageTitle.bezeled = NO;
  imageTitle.drawsBackground = NO;
  imageTitle.editable = NO;
  [self.view addSubview:imageTitle];
  y -= 30;
  
  // Compression quality label and value
  NSTextField *compressionTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, 200, 17)];
  compressionTitle.stringValue = @"Compression Quality:";
  compressionTitle.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
  compressionTitle.textColor = [NSColor secondaryLabelColor];
  compressionTitle.bezeled = NO;
  compressionTitle.drawsBackground = NO;
  compressionTitle.editable = NO;
  [self.view addSubview:compressionTitle];
  
  self.compressionLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding + contentWidth - 100, y, 100, 17)];
  self.compressionLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
  self.compressionLabel.textColor = [NSColor secondaryLabelColor];
  self.compressionLabel.bezeled = NO;
  self.compressionLabel.drawsBackground = NO;
  self.compressionLabel.editable = NO;
  self.compressionLabel.alignment = NSTextAlignmentRight;
  [self.view addSubview:self.compressionLabel];
  y -= 25;
  
  // Compression slider (0 = off, 10-90 = quality)
  self.compressionSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 20)];
  self.compressionSlider.minValue = 0;
  self.compressionSlider.maxValue = 90;
  self.compressionSlider.numberOfTickMarks = 10;
  self.compressionSlider.allowsTickMarkValuesOnly = YES;
  self.compressionSlider.target = self;
  self.compressionSlider.action = @selector(compressionChanged:);
  [self.view addSubview:self.compressionSlider];
  y -= 35;
  
  // Remove EXIF checkbox
  self.removeEXIFCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(padding, y, contentWidth, 20)];
  self.removeEXIFCheckbox.title = @"Remove EXIF metadata from images";
  [self.removeEXIFCheckbox setButtonType:NSButtonTypeSwitch];
  self.removeEXIFCheckbox.target = self;
  self.removeEXIFCheckbox.action = @selector(removeEXIFChanged:);
  [self.view addSubview:self.removeEXIFCheckbox];
  y -= 30;
  
  // Image processing hint
  NSTextField *imageHintLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding, y - 10, contentWidth, 40)];
  imageHintLabel.stringValue = @"Compression applies only to images (JPG, PNG, GIF, BMP, TIFF, etc.). "
                                @"Set to 0 to disable. EXIF removal protects privacy.";
  imageHintLabel.font = [NSFont systemFontOfSize:11];
  imageHintLabel.textColor = [NSColor tertiaryLabelColor];
  imageHintLabel.bezeled = NO;
  imageHintLabel.drawsBackground = NO;
  imageHintLabel.editable = NO;
  imageHintLabel.lineBreakMode = NSLineBreakByWordWrapping;
  imageHintLabel.maximumNumberOfLines = 2;
  [self.view addSubview:imageHintLabel];
}

- (void)loadSettings {
  MSTOutputFormat format = [MSTConfigManager sharedManager].outputFormat;
  self.outputFormatControl.selectedSegment = format;
  [self updatePreview];

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
}

- (void)outputFormatChanged:(NSSegmentedControl *)sender {
  [MSTConfigManager sharedManager].outputFormat = sender.selectedSegment;
  [[MSTConfigManager sharedManager] saveConfigs];
  [self updatePreview];
}

- (void)updatePreview {
  NSString *sampleURL = @"https://example.com/image.png";
  NSString *preview;

  switch (self.outputFormatControl.selectedSegment) {
  case 0:
    preview = sampleURL;
    break;
  case 1:
    preview = [NSString stringWithFormat:@"![image](%@)", sampleURL];
    break;
  case 2:
    preview = [NSString stringWithFormat:@"<img src=\"%@\" />", sampleURL];
    break;
  case 3:
    preview = [NSString stringWithFormat:@"[img]%@[/img]", sampleURL];
    break;
  default:
    preview = sampleURL;
  }

  self.previewLabel.stringValue = [NSString stringWithFormat:@" %@", preview];
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

@end
