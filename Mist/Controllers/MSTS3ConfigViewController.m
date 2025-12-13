//
//  MSTS3ConfigViewController.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTS3ConfigViewController.h"
#import "MSTConfigManager.h"
#import "MSTS3HostConfig.h"
#import "MSTS3Region.h"
#import "MSTS3Uploader.h"

@interface MSTS3ConfigViewController () <NSTextFieldDelegate>

@property(nonatomic, strong) NSScrollView *scrollView;
@property(nonatomic, strong) NSView *contentView;

@property(nonatomic, strong) NSTextField *nameField;
@property(nonatomic, strong) NSPopUpButton *providerPopup;
@property(nonatomic, strong) NSPopUpButton *regionPopup;
@property(nonatomic, strong) NSTextField *endpointField;
@property(nonatomic, strong) NSTextField *bucketField;
@property(nonatomic, strong) NSSecureTextField *accessKeyField;
@property(nonatomic, strong) NSSecureTextField *secretKeyField;
@property(nonatomic, strong) NSButton *showAccessKeyButton;
@property(nonatomic, strong) NSButton *showSecretKeyButton;
@property(nonatomic, strong) NSPopUpButton *aclPopup;
@property(nonatomic, strong) NSTextField *domainField;
@property(nonatomic, strong) NSTextField *saveKeyPathField;

@property(nonatomic, strong) NSTextField *regionLabel;
@property(nonatomic, strong) NSTextField *endpointLabel;

@property(nonatomic, strong) NSImageView *providerIconView;
@property(nonatomic, strong) NSTextField *connectionSectionLabel;
@property(nonatomic, strong) NSTextField *credentialsSectionLabel;
@property(nonatomic, strong) NSTextField *outputSectionLabel;

@property(nonatomic, strong) NSButton *validateButton;
@property(nonatomic, strong) NSButton *saveButton;
@property(nonatomic, strong) NSTextField *statusLabel;

@property(nonatomic, strong) NSView *emptyView;

@property(nonatomic, assign) BOOL showingAccessKey;
@property(nonatomic, assign) BOOL showingSecretKey;

@end

@implementation MSTS3ConfigViewController

- (instancetype)init {
  self = [super initWithNibName:nil bundle:nil];
  return self;
}

- (void)loadView {
  self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 480, 480)];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupUI];
  [self showEmptyState];
}

- (void)setupUI {
  // Empty state view
  self.emptyView = [[NSView alloc] initWithFrame:self.view.bounds];
  self.emptyView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  NSImageView *emptyIcon =
      [[NSImageView alloc] initWithFrame:NSMakeRect(175, 220, 100, 100)];
  emptyIcon.image = [NSImage imageWithSystemSymbolName:@"server.rack"
                              accessibilityDescription:@"No host"];
  emptyIcon.contentTintColor = [NSColor tertiaryLabelColor];
  emptyIcon.autoresizingMask =
      NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin;
  [self.emptyView addSubview:emptyIcon];

  NSTextField *emptyLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(100, 180, 250, 30)];
  emptyLabel.stringValue = @"Select a host or add a new one";
  emptyLabel.alignment = NSTextAlignmentCenter;
  emptyLabel.bezeled = NO;
  emptyLabel.drawsBackground = NO;
  emptyLabel.editable = NO;
  emptyLabel.textColor = [NSColor secondaryLabelColor];
  emptyLabel.autoresizingMask =
      NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin;
  [self.emptyView addSubview:emptyLabel];

  [self.view addSubview:self.emptyView];

  // Scroll view for config form
  self.scrollView = [[NSScrollView alloc] initWithFrame:self.view.bounds];
  self.scrollView.hasVerticalScroller = YES;
  self.scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.scrollView.hidden = YES;

  self.contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 450, 460)];

  CGFloat y = 430;
  CGFloat fieldX = 120;
  CGFloat fieldWidth = 300;
  CGFloat row = 30;  // uniform row spacing

  // Name
  [self addLabel:@"Name:" atY:y];
  self.nameField = [self createTextFieldAtX:fieldX y:y width:fieldWidth - 36];
  self.nameField.placeholderString = @"My S3 Host";
  self.nameField.delegate = self;
  [self.contentView addSubview:self.nameField];

  self.providerIconView =
      [[NSImageView alloc] initWithFrame:NSMakeRect(fieldX + fieldWidth - 28, y - 1, 24, 24)];
  self.providerIconView.imageScaling = NSImageScaleProportionallyUpOrDown;
  self.providerIconView.image = [NSImage imageNamed:@"aws"];
  [self.contentView addSubview:self.providerIconView];
  y -= row;

  // Provider
  [self addLabel:@"Provider:" atY:y];
  self.providerPopup = [[NSPopUpButton alloc]
      initWithFrame:NSMakeRect(fieldX, y, fieldWidth, 22)];
  for (MSTS3ProviderType type = MSTS3ProviderTypeAmazonS3;
       type <= MSTS3ProviderTypeCustom; type++) {
    [self.providerPopup
        addItemWithTitle:[MSTS3Region displayNameForProvider:type]];
    self.providerPopup.lastItem.tag = type;
  }
  self.providerPopup.target = self;
  self.providerPopup.action = @selector(providerChanged:);
  [self.contentView addSubview:self.providerPopup];
  y -= row;

  // Region (AWS only)
  self.regionLabel = [self addLabel:@"Region:" atY:y];
  self.regionPopup = [[NSPopUpButton alloc]
      initWithFrame:NSMakeRect(fieldX, y, fieldWidth, 22)];
  [self updateRegionsForProvider:MSTS3ProviderTypeAmazonS3];
  [self.contentView addSubview:self.regionPopup];
  y -= row;

  // Endpoint (non-AWS)
  self.endpointLabel = [self addLabel:@"Endpoint:" atY:y];
  self.endpointField = [self createTextFieldAtX:fieldX y:y width:fieldWidth];
  self.endpointField.placeholderString = @"s3.us-west-004.backblazeb2.com";
  self.endpointField.delegate = self;
  [self.contentView addSubview:self.endpointField];
  self.endpointLabel.hidden = YES;
  self.endpointField.hidden = YES;
  y -= row;

  // Bucket
  [self addLabel:@"Bucket:" atY:y];
  self.bucketField = [self createTextFieldAtX:fieldX y:y width:fieldWidth];
  self.bucketField.placeholderString = @"my-bucket";
  self.bucketField.delegate = self;
  [self.contentView addSubview:self.bucketField];
  y -= row;

  // Access Key
  [self addLabel:@"Access Key:" atY:y];
  self.accessKeyField = [[NSSecureTextField alloc]
      initWithFrame:NSMakeRect(fieldX, y, fieldWidth - 28, 22)];
  self.accessKeyField.placeholderString = @"AKIAIOSFODNN7EXAMPLE";
  self.accessKeyField.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
  self.accessKeyField.delegate = self;
  [self.contentView addSubview:self.accessKeyField];

  self.showAccessKeyButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(fieldX + fieldWidth - 24, y, 24, 22)];
  self.showAccessKeyButton.bezelStyle = NSBezelStyleInline;
  self.showAccessKeyButton.bordered = NO;
  self.showAccessKeyButton.image = [NSImage imageWithSystemSymbolName:@"eye"
                                             accessibilityDescription:@"Show"];
  self.showAccessKeyButton.target = self;
  self.showAccessKeyButton.action = @selector(toggleAccessKeyVisibility:);
  [self.contentView addSubview:self.showAccessKeyButton];
  y -= row;

  // Secret Key
  [self addLabel:@"Secret Key:" atY:y];
  self.secretKeyField = [[NSSecureTextField alloc]
      initWithFrame:NSMakeRect(fieldX, y, fieldWidth - 28, 22)];
  self.secretKeyField.placeholderString = @"wJalrXUtnFEMI/K7MDENG/bPxRfi...";
  self.secretKeyField.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
  self.secretKeyField.delegate = self;
  [self.contentView addSubview:self.secretKeyField];

  self.showSecretKeyButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(fieldX + fieldWidth - 24, y, 24, 22)];
  self.showSecretKeyButton.bezelStyle = NSBezelStyleInline;
  self.showSecretKeyButton.bordered = NO;
  self.showSecretKeyButton.image = [NSImage imageWithSystemSymbolName:@"eye"
                                             accessibilityDescription:@"Show"];
  self.showSecretKeyButton.target = self;
  self.showSecretKeyButton.action = @selector(toggleSecretKeyVisibility:);
  [self.contentView addSubview:self.showSecretKeyButton];
  y -= row;

  // ACL
  [self addLabel:@"ACL:" atY:y];
  self.aclPopup = [[NSPopUpButton alloc]
      initWithFrame:NSMakeRect(fieldX, y, fieldWidth, 22)];
  [self.aclPopup addItemWithTitle:@"Private"];
  self.aclPopup.lastItem.representedObject = @"private";
  [self.aclPopup addItemWithTitle:@"Public Read"];
  self.aclPopup.lastItem.representedObject = @"public-read";
  [self.aclPopup addItemWithTitle:@"Public Read Write"];
  self.aclPopup.lastItem.representedObject = @"public-read-write";
  [self.aclPopup addItemWithTitle:@"Authenticated Read"];
  self.aclPopup.lastItem.representedObject = @"authenticated-read";
  [self.contentView addSubview:self.aclPopup];
  y -= row;

  // Custom Domain
  [self addLabel:@"Domain:" atY:y];
  self.domainField = [self createTextFieldAtX:fieldX y:y width:fieldWidth];
  self.domainField.placeholderString = @"cdn.example.com (optional)";
  self.domainField.delegate = self;
  [self.contentView addSubview:self.domainField];
  y -= row;

  // Save Path
  [self addLabel:@"Save Path:" atY:y];
  self.saveKeyPathField = [self createTextFieldAtX:fieldX y:y width:fieldWidth];
  self.saveKeyPathField.placeholderString = @"{filename}.{ext}";
  self.saveKeyPathField.delegate = self;
  [self.contentView addSubview:self.saveKeyPathField];
  y -= 18;

  NSTextField *pathHint =
      [[NSTextField alloc] initWithFrame:NSMakeRect(fieldX, y, fieldWidth, 12)];
  pathHint.stringValue = @"{year} {month} {day} {filename} {ext} {random} {uuid}";
  pathHint.font = [NSFont systemFontOfSize:9];
  pathHint.textColor = [NSColor tertiaryLabelColor];
  pathHint.bezeled = NO;
  pathHint.drawsBackground = NO;
  pathHint.editable = NO;
  [self.contentView addSubview:pathHint];
  y -= row;

  // Buttons
  self.statusLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y + 2, 140, 18)];
  self.statusLabel.stringValue = @"";
  self.statusLabel.bezeled = NO;
  self.statusLabel.drawsBackground = NO;
  self.statusLabel.editable = NO;
  self.statusLabel.font = [NSFont systemFontOfSize:11];
  [self.contentView addSubview:self.statusLabel];

  self.saveButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(fieldX + fieldWidth - 75, y, 75, 24)];
  self.saveButton.title = @"Save";
  self.saveButton.bezelStyle = NSBezelStyleRounded;
  self.saveButton.keyEquivalent = @"\r";
  self.saveButton.target = self;
  self.saveButton.action = @selector(saveConfig:);
  [self.contentView addSubview:self.saveButton];

  self.validateButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(fieldX + fieldWidth - 158, y, 75, 24)];
  self.validateButton.title = @"Validate";
  self.validateButton.bezelStyle = NSBezelStyleRounded;
  self.validateButton.target = self;
  self.validateButton.action = @selector(validateConfig:);
  [self.contentView addSubview:self.validateButton];

  self.scrollView.documentView = self.contentView;
  [self.view addSubview:self.scrollView];
}

- (NSTextField *)addLabel:(NSString *)text atY:(CGFloat)y {
  NSTextField *label =
      [[NSTextField alloc] initWithFrame:NSMakeRect(16, y + 1, 100, 18)];
  label.stringValue = text;
  label.alignment = NSTextAlignmentRight;
  label.bezeled = NO;
  label.drawsBackground = NO;
  label.editable = NO;
  label.font = [NSFont systemFontOfSize:13];
  label.textColor = [NSColor secondaryLabelColor];
  [self.contentView addSubview:label];
  return label;
}

- (NSTextField *)addSectionHeader:(NSString *)text atY:(CGFloat)y {
  NSTextField *header =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 400, 16)];
  header.stringValue = text;
  header.bezeled = NO;
  header.drawsBackground = NO;
  header.editable = NO;
  header.font = [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold];
  header.textColor = [NSColor secondaryLabelColor];
  [self.contentView addSubview:header];
  return header;
}

- (NSTextField *)createTextFieldAtX:(CGFloat)x
                                  y:(CGFloat)y
                              width:(CGFloat)width {
  NSTextField *field =
      [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, width, 22)];
  field.bezelStyle = NSTextFieldRoundedBezel;
  field.cell.lineBreakMode = NSLineBreakByTruncatingTail;
  field.cell.scrollable = YES;
  return field;
}

- (void)showEmptyState {
  self.emptyView.hidden = NO;
  self.scrollView.hidden = YES;
}

- (void)showConfigEditor {
  self.emptyView.hidden = YES;
  self.scrollView.hidden = NO;
}

- (void)setConfig:(MSTS3HostConfig *)config {
  _config = config;

  if (!config) {
    [self showEmptyState];
    return;
  }

  [self showConfigEditor];
  [self loadConfigToUI];
}

- (void)loadConfigToUI {
  if (!self.config)
    return;

  self.nameField.stringValue = self.config.name ?: @"";

  // Provider
  [self.providerPopup selectItemWithTag:self.config.providerType];
  [self updateRegionsForProvider:self.config.providerType];

  self.endpointField.stringValue = self.config.endpoint ?: @"";
  self.bucketField.stringValue = self.config.bucket ?: @"";
  self.accessKeyField.stringValue = self.config.accessKey ?: @"";
  self.secretKeyField.stringValue = self.config.secretKey ?: @"";
  self.domainField.stringValue = self.config.domain ?: @"";
  self.saveKeyPathField.stringValue =
      self.config.saveKeyPath ?: @"{year}/{month}/{day}/{filename}.{ext}";

  // Region
  for (NSMenuItem *item in self.regionPopup.itemArray) {
    if ([item.representedObject isEqualToString:self.config.region]) {
      [self.regionPopup selectItem:item];
      break;
    }
  }

  // ACL
  for (NSMenuItem *item in self.aclPopup.itemArray) {
    if ([item.representedObject isEqualToString:self.config.acl]) {
      [self.aclPopup selectItem:item];
      break;
    }
  }

  [self updateFieldVisibility];
  [self updateProviderIcon:self.config.providerType];
  self.statusLabel.stringValue = @"";

  // Scroll to top of form so Name field is visible
  NSPoint topPoint = NSMakePoint(0, self.contentView.frame.size.height);
  [self.scrollView.documentView scrollPoint:topPoint];
}

- (void)providerChanged:(NSPopUpButton *)sender {
  MSTS3ProviderType provider = (MSTS3ProviderType)sender.selectedItem.tag;
  [self updateRegionsForProvider:provider];
  [self updateFieldVisibility];
  [self updateProviderIcon:provider];

  // Auto-select first region for providers with fixed regions (Wasabi, R2)
  if (provider == MSTS3ProviderTypeWasabi ||
      provider == MSTS3ProviderTypeCloudflareR2) {
    [self.regionPopup selectItemAtIndex:0];
  }
}

- (void)updateProviderIcon:(MSTS3ProviderType)provider {
  NSString *iconName;
  switch (provider) {
  case MSTS3ProviderTypeAmazonS3:
    iconName = @"aws";
    break;
  case MSTS3ProviderTypeWasabi:
    iconName = @"wasabi";
    break;
  case MSTS3ProviderTypeCloudflareR2:
    iconName = @"cloudflare";
    break;
  case MSTS3ProviderTypeBackblazeB2:
    iconName = @"backblaze";
    break;
  case MSTS3ProviderTypeCustom:
  default:
    iconName = @"custom";
    break;
  }
  self.providerIconView.image = [NSImage imageNamed:iconName];
}

- (void)updateRegionsForProvider:(MSTS3ProviderType)provider {
  [self.regionPopup removeAllItems];
  for (MSTS3Region *region in [MSTS3Region regionsForProvider:provider]) {
    [self.regionPopup addItemWithTitle:region.displayName];
    self.regionPopup.lastItem.representedObject = region.identifier;
  }
}

- (void)updateFieldVisibility {
  MSTS3ProviderType provider =
      (MSTS3ProviderType)self.providerPopup.selectedItem.tag;
  BOOL needsEndpoint = (provider != MSTS3ProviderTypeAmazonS3);
  BOOL needsRegion = (provider == MSTS3ProviderTypeAmazonS3);

  self.regionLabel.hidden = !needsRegion;
  self.regionPopup.hidden = !needsRegion;
  self.endpointLabel.hidden = !needsEndpoint;
  self.endpointField.hidden = !needsEndpoint;

  // When Region is hidden, move Endpoint up to Region's position
  CGFloat regionY = self.regionPopup.frame.origin.y;

  if (!needsRegion && needsEndpoint) {
    NSRect labelFrame = self.endpointLabel.frame;
    labelFrame.origin.y = regionY + 1;
    self.endpointLabel.frame = labelFrame;

    NSRect fieldFrame = self.endpointField.frame;
    fieldFrame.origin.y = regionY;
    self.endpointField.frame = fieldFrame;
  }
}

- (void)toggleAccessKeyVisibility:(id)sender {
  self.showingAccessKey = !self.showingAccessKey;
  NSString *value = self.accessKeyField.stringValue;

  NSTextField *newField;
  if (self.showingAccessKey) {
    newField = [[NSTextField alloc] initWithFrame:self.accessKeyField.frame];
    self.showAccessKeyButton.image =
        [NSImage imageWithSystemSymbolName:@"eye.slash"
                  accessibilityDescription:@"Hide"];
  } else {
    newField =
        [[NSSecureTextField alloc] initWithFrame:self.accessKeyField.frame];
    self.showAccessKeyButton.image =
        [NSImage imageWithSystemSymbolName:@"eye"
                  accessibilityDescription:@"Show"];
  }

  newField.stringValue = value;
  newField.placeholderString = self.accessKeyField.placeholderString;
  newField.delegate = self;

  [self.accessKeyField removeFromSuperview];
  [self.contentView addSubview:newField];
  self.accessKeyField = (NSSecureTextField *)newField;
}

- (void)toggleSecretKeyVisibility:(id)sender {
  self.showingSecretKey = !self.showingSecretKey;
  NSString *value = self.secretKeyField.stringValue;

  NSTextField *newField;
  if (self.showingSecretKey) {
    newField = [[NSTextField alloc] initWithFrame:self.secretKeyField.frame];
    self.showSecretKeyButton.image =
        [NSImage imageWithSystemSymbolName:@"eye.slash"
                  accessibilityDescription:@"Hide"];
  } else {
    newField =
        [[NSSecureTextField alloc] initWithFrame:self.secretKeyField.frame];
    self.showSecretKeyButton.image =
        [NSImage imageWithSystemSymbolName:@"eye"
                  accessibilityDescription:@"Show"];
  }

  newField.stringValue = value;
  newField.placeholderString = self.secretKeyField.placeholderString;
  newField.delegate = self;

  [self.secretKeyField removeFromSuperview];
  [self.contentView addSubview:newField];
  self.secretKeyField = (NSSecureTextField *)newField;
}

- (void)saveConfig:(id)sender {
  if (!self.config)
    return;

  self.config.name = self.nameField.stringValue;
  self.config.providerType =
      (MSTS3ProviderType)self.providerPopup.selectedItem.tag;
  self.config.region = self.regionPopup.selectedItem.representedObject;
  self.config.endpoint = self.endpointField.stringValue;
  self.config.bucket = self.bucketField.stringValue;
  self.config.accessKey = self.accessKeyField.stringValue;
  self.config.secretKey = self.secretKeyField.stringValue;
  self.config.acl = self.aclPopup.selectedItem.representedObject;
  self.config.domain = self.domainField.stringValue;

  NSString *savePath = self.saveKeyPathField.stringValue;
  self.config.saveKeyPath =
      savePath.length > 0 ? savePath : @"{filename}.{ext}";

  [[MSTConfigManager sharedManager] updateHostConfig:self.config];

  self.statusLabel.stringValue = @"✓ Saved";
  self.statusLabel.textColor = [NSColor systemGreenColor];
  self.statusLabel.font = [NSFont boldSystemFontOfSize:12];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
                   self.statusLabel.stringValue = @"";
                   self.statusLabel.font = [NSFont systemFontOfSize:11];
                 });
}

- (void)validateConfig:(id)sender {
  self.validateButton.enabled = NO;
  self.statusLabel.stringValue = @"Validating...";
  self.statusLabel.textColor = [NSColor labelColor];

  // Create temp config
  MSTS3HostConfig *testConfig = [[MSTS3HostConfig alloc] init];
  testConfig.providerType =
      (MSTS3ProviderType)self.providerPopup.selectedItem.tag;
  testConfig.region = self.regionPopup.selectedItem.representedObject;
  testConfig.endpoint = self.endpointField.stringValue;
  testConfig.bucket = self.bucketField.stringValue;
  testConfig.accessKey = self.accessKeyField.stringValue;
  testConfig.secretKey = self.secretKeyField.stringValue;
  testConfig.acl = self.aclPopup.selectedItem.representedObject;
  testConfig.domain = self.domainField.stringValue;

  NSData *testData =
      [@"Mist validation test" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *testFilename =
      [NSString stringWithFormat:@"_mist_test_%ld.txt",
                                 (long)[[NSDate date] timeIntervalSince1970]];

  [[MSTS3Uploader sharedUploader]
      uploadData:testData
        filename:testFilename
      withConfig:testConfig
        progress:nil
      completion:^(NSString *url, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
          self.validateButton.enabled = YES;
          if (error) {
            self.statusLabel.stringValue = @"Validation failed!";
            self.statusLabel.textColor = [NSColor systemRedColor];
          } else {
            self.statusLabel.stringValue = @"Validation successful!";
            self.statusLabel.textColor = [NSColor systemGreenColor];
          }
        });
      }];
}

@end
