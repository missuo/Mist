//
//  MSTAboutViewController.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTAboutViewController.h"
#import "MSTS3Region.h"

@implementation MSTAboutViewController

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
}

- (NSTextField *)addCenteredLabel:(NSString *)text
                             font:(NSFont *)font
                            color:(NSColor *)color
                                y:(CGFloat)y
                           height:(CGFloat)height {
  NSTextField *label = [[NSTextField alloc]
      initWithFrame:NSMakeRect(0, y, self.view.bounds.size.width, height)];
  label.stringValue = text;
  label.font = font;
  label.textColor = color;
  label.alignment = NSTextAlignmentCenter;
  label.bezeled = NO;
  label.drawsBackground = NO;
  label.editable = NO;
  label.selectable = NO;
  [self.view addSubview:label];
  return label;
}

- (void)setupUI {
  CGFloat width = self.view.bounds.size.width;
  CGFloat centerX = width / 2;
  CGFloat y = self.view.bounds.size.height - 36;

  // App Icon
  y -= 96;
  NSImageView *iconView =
      [[NSImageView alloc] initWithFrame:NSMakeRect(centerX - 48, y, 96, 96)];
  NSImage *icon = [NSImage imageNamed:@"AppIcon"];
  if (!icon) {
    icon = [NSApp applicationIconImage];
  }
  iconView.image = icon;
  iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
  [self.view addSubview:iconView];

  // App Name
  y -= 10 + 34;
  [self addCenteredLabel:@"Mist"
                    font:[NSFont systemFontOfSize:26 weight:NSFontWeightBold]
                   color:[NSColor labelColor]
                       y:y
                  height:34];

  // Version
  y -= 2 + 18;
  NSString *version =
      [[NSBundle mainBundle]
          objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
          ?: @"1.0";
  NSString *build =
      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]
          ?: @"1";
  [self addCenteredLabel:[NSString
                             stringWithFormat:@"Version %@ (%@)", version, build]
                    font:[NSFont systemFontOfSize:12]
                   color:[NSColor secondaryLabelColor]
                       y:y
                  height:18];

  // Description
  y -= 12 + 20;
  [self addCenteredLabel:@"A native macOS menu bar uploader for S3-compatible "
                         @"storage and S.EE"
                    font:[NSFont systemFontOfSize:13]
                   color:[NSColor secondaryLabelColor]
                       y:y
                  height:20];

  // Supported providers
  y -= 20 + 28;
  NSArray<NSNumber *> *providers = @[
    @(MSTS3ProviderTypeAmazonS3), @(MSTS3ProviderTypeWasabi),
    @(MSTS3ProviderTypeCloudflareR2), @(MSTS3ProviderTypeBackblazeB2),
    @(MSTS3ProviderTypeMinIO), @(MSTS3ProviderTypeCustom),
    @(MSTS3ProviderTypeSEE)
  ];
  CGFloat iconSize = 28;
  CGFloat iconGap = 16;
  CGFloat rowWidth =
      providers.count * iconSize + (providers.count - 1) * iconGap;
  CGFloat iconX = centerX - rowWidth / 2;
  for (NSNumber *provider in providers) {
    MSTS3ProviderType type = provider.integerValue;
    NSImageView *providerIcon = [[NSImageView alloc]
        initWithFrame:NSMakeRect(iconX, y, iconSize, iconSize)];
    providerIcon.image =
        [NSImage imageNamed:[MSTS3Region iconNameForProvider:type]];
    providerIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
    providerIcon.toolTip = [MSTS3Region displayNameForProvider:type];
    [self.view addSubview:providerIcon];
    iconX += iconSize + iconGap;
  }

  // Website + GitHub buttons
  y -= 24 + 24;
  NSButton *websiteButton = [NSButton buttonWithTitle:@"Website"
                                               target:self
                                               action:@selector(openWebsite:)];
  websiteButton.bezelStyle = NSBezelStyleRounded;
  [websiteButton sizeToFit];

  NSButton *githubButton = [NSButton buttonWithTitle:@"View on GitHub"
                                              target:self
                                              action:@selector(openGitHub:)];
  githubButton.bezelStyle = NSBezelStyleRounded;
  [githubButton sizeToFit];

  CGFloat buttonGap = 12;
  CGFloat buttonsWidth = websiteButton.frame.size.width + buttonGap +
                         githubButton.frame.size.width;
  [websiteButton setFrameOrigin:NSMakePoint(centerX - buttonsWidth / 2, y)];
  [githubButton
      setFrameOrigin:NSMakePoint(centerX - buttonsWidth / 2 +
                                     websiteButton.frame.size.width + buttonGap,
                                 y)];
  [self.view addSubview:websiteButton];
  [self.view addSubview:githubButton];

  // uPic acknowledgment — Mist started life as a uPic-inspired rewrite
  NSButton *upicLink =
      [NSButton buttonWithTitle:@"Built upon the great work of uPic ❤️"
                         target:self
                         action:@selector(openUPic:)];
  upicLink.bordered = NO;
  upicLink.attributedTitle = [[NSAttributedString alloc]
      initWithString:upicLink.title
          attributes:@{
            NSForegroundColorAttributeName : [NSColor secondaryLabelColor],
            NSFontAttributeName : [NSFont systemFontOfSize:11],
          }];
  [upicLink sizeToFit];
  [upicLink setFrameOrigin:NSMakePoint(centerX - upicLink.frame.size.width / 2,
                                       64)];
  [self.view addSubview:upicLink];

  // Credits (pinned at the bottom)
  [self addCenteredLabel:@"Made with 💙 in SF"
                    font:[NSFont systemFontOfSize:11]
                   color:[NSColor tertiaryLabelColor]
                       y:44
                  height:16];
  [self addCenteredLabel:@"© 2025 OwO Network, LLC"
                    font:[NSFont systemFontOfSize:11]
                   color:[NSColor tertiaryLabelColor]
                       y:24
                  height:16];
}

- (void)openWebsite:(id)sender {
  [[NSWorkspace sharedWorkspace]
      openURL:[NSURL URLWithString:@"https://mist.ws"]];
}

- (void)openGitHub:(id)sender {
  [[NSWorkspace sharedWorkspace]
      openURL:[NSURL URLWithString:@"https://github.com/missuo/Mist"]];
}

- (void)openUPic:(id)sender {
  [[NSWorkspace sharedWorkspace]
      openURL:[NSURL URLWithString:@"https://github.com/gee1k/uPic"]];
}

@end
