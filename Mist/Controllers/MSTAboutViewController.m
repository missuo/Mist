//
//  MSTAboutViewController.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTAboutViewController.h"

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

- (void)setupUI {
  CGFloat centerX = self.view.bounds.size.width / 2;
  CGFloat y = self.view.bounds.size.height;

  // App Icon (64x64)
  y -= 20; // top margin
  y -= 64; // icon height
  NSImageView *iconView =
      [[NSImageView alloc] initWithFrame:NSMakeRect(centerX - 32, y, 64, 64)];
  NSImage *icon = [NSImage imageNamed:@"AppIcon"];
  if (!icon) {
    icon = [NSApp applicationIconImage];
  }
  iconView.image = icon;
  iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
  [self.view addSubview:iconView];

  // App Name
  y -= 8;  // spacing
  y -= 28; // label height
  NSTextField *nameLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(0, y, self.view.bounds.size.width, 28)];
  nameLabel.stringValue = @"Mist";
  nameLabel.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
  nameLabel.alignment = NSTextAlignmentCenter;
  nameLabel.textColor = [NSColor labelColor];
  nameLabel.bezeled = NO;
  nameLabel.drawsBackground = NO;
  nameLabel.editable = NO;
  [self.view addSubview:nameLabel];

  // Version
  y -= 4;  // spacing
  y -= 18; // label height
  NSString *version =
      [[NSBundle mainBundle]
          objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
          ?: @"1.0";
  NSString *build =
      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]
          ?: @"1";
  NSTextField *versionLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(0, y, self.view.bounds.size.width, 18)];
  versionLabel.stringValue =
      [NSString stringWithFormat:@"Version %@ (%@)", version, build];
  versionLabel.font = [NSFont systemFontOfSize:11];
  versionLabel.textColor = [NSColor secondaryLabelColor];
  versionLabel.alignment = NSTextAlignmentCenter;
  versionLabel.bezeled = NO;
  versionLabel.drawsBackground = NO;
  versionLabel.editable = NO;
  [self.view addSubview:versionLabel];

  // Description
  y -= 12; // spacing
  y -= 18; // label height
  NSTextField *descLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(20, y, self.view.bounds.size.width - 40, 18)];
  descLabel.stringValue = @"A lightweight S3 image uploader for macOS";
  descLabel.font = [NSFont systemFontOfSize:12];
  descLabel.textColor = [NSColor secondaryLabelColor];
  descLabel.alignment = NSTextAlignmentCenter;
  descLabel.bezeled = NO;
  descLabel.drawsBackground = NO;
  descLabel.editable = NO;
  [self.view addSubview:descLabel];

  // Made with love message
  NSTextField *madeWithLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(0, 38, self.view.bounds.size.width, 16)];
  madeWithLabel.stringValue = @"Made with 💙 from SF";
  madeWithLabel.font = [NSFont systemFontOfSize:10];
  madeWithLabel.textColor = [NSColor tertiaryLabelColor];
  madeWithLabel.alignment = NSTextAlignmentCenter;
  madeWithLabel.bezeled = NO;
  madeWithLabel.drawsBackground = NO;
  madeWithLabel.editable = NO;
  [self.view addSubview:madeWithLabel];

  // Copyright (fixed at bottom)
  NSTextField *copyrightLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(0, 20, self.view.bounds.size.width, 16)];
  copyrightLabel.stringValue = @"© 2025 OwO Network, LLC";
  copyrightLabel.font = [NSFont systemFontOfSize:10];
  copyrightLabel.textColor = [NSColor tertiaryLabelColor];
  copyrightLabel.alignment = NSTextAlignmentCenter;
  copyrightLabel.bezeled = NO;
  copyrightLabel.drawsBackground = NO;
  copyrightLabel.editable = NO;
  [self.view addSubview:copyrightLabel];
}

@end
