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
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *MSTStripWhitespaceAndNewlines(NSString *value) {
  if (!value) {
    return @"";
  }
  NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSArray<NSString *> *components =
      [value componentsSeparatedByCharactersInSet:set];
  NSMutableArray<NSString *> *filtered = [NSMutableArray array];
  for (NSString *part in components) {
    if (part.length > 0) {
      [filtered addObject:part];
    }
  }
  return [filtered componentsJoinedByString:@""];
}

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
@property(nonatomic, strong) NSTextField *tokenLabel;
@property(nonatomic, strong) NSSecureTextField *tokenField;
@property(nonatomic, strong) NSTextField *bucketLabel;
@property(nonatomic, strong) NSTextField *accessKeyLabel;
@property(nonatomic, strong) NSTextField *secretKeyLabel;
@property(nonatomic, strong) NSTextField *aclLabel;
@property(nonatomic, strong) NSTextField *urlPrefixLabel;
@property(nonatomic, strong) NSTextField *savePathLabel;
@property(nonatomic, strong) NSButton *useHTTPSCheckbox;
@property(nonatomic, strong) NSTextField *pathHintLabel;
@property(nonatomic, strong) NSButton *showAccessKeyButton;
@property(nonatomic, strong) NSButton *showSecretKeyButton;
@property(nonatomic, strong) NSPopUpButton *aclPopup;
@property(nonatomic, strong) NSTextField *urlPrefixField;
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
@property(nonatomic, strong) NSButton *shortLinkCheckbox;
@property(nonatomic, strong) NSTextField *shortLinkNoteLabel;

@property(nonatomic, strong) NSView *emptyView;

@property(nonatomic, assign) BOOL showingAccessKey;
@property(nonatomic, assign) BOOL showingSecretKey;

// Layout baselines
@property(nonatomic, assign) NSRect baseTokenLabelFrame;
@property(nonatomic, assign) NSRect baseTokenFieldFrame;
@property(nonatomic, assign) NSRect baseShortLinkCheckboxFrame;
@property(nonatomic, assign) NSRect baseShortLinkNoteFrame;
@property(nonatomic, assign) NSRect baseSavePathLabelFrame;
@property(nonatomic, assign) NSRect baseSaveKeyPathFieldFrame;
@property(nonatomic, assign) NSRect basePathHintFrame;
@property(nonatomic, assign) NSRect baseStatusLabelFrame;
@property(nonatomic, assign) NSRect baseSaveButtonFrame;
@property(nonatomic, assign) NSRect baseValidateButtonFrame;

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

  self.contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 450, 530)];

  CGFloat y = 500;
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
       type <= MSTS3ProviderTypeSMMS; type++) {
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
  self.bucketLabel = [self addLabel:@"Bucket:" atY:y];
  self.bucketField = [self createTextFieldAtX:fieldX y:y width:fieldWidth];
  self.bucketField.placeholderString = @"my-bucket";
  self.bucketField.delegate = self;
  [self.contentView addSubview:self.bucketField];
  y -= row;

  // Access Key
  self.accessKeyLabel = [self addLabel:@"Access Key:" atY:y];
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
  self.secretKeyLabel = [self addLabel:@"Secret Key:" atY:y];
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

  // SM.MS Token
  self.tokenLabel = [self addLabel:@"Token:" atY:y];
  self.tokenField = [[NSSecureTextField alloc]
      initWithFrame:NSMakeRect(fieldX, y, fieldWidth, 22)];
  self.tokenField.placeholderString = @"SM.MS API token";
  self.tokenField.font =
      [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
  self.tokenField.delegate = self;
  self.tokenLabel.hidden = YES;
  self.tokenField.hidden = YES;
  [self.contentView addSubview:self.tokenField];
  y -= row;

  // ACL
  self.aclLabel = [self addLabel:@"ACL:" atY:y];
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

  // URL Prefix
  self.urlPrefixLabel = [self addLabel:@"URL Prefix:" atY:y];
  self.urlPrefixField = [self createTextFieldAtX:fieldX y:y width:fieldWidth];
  self.urlPrefixField.placeholderString = @"cdn.example.com (optional)";
  self.urlPrefixField.delegate = self;
  [self.contentView addSubview:self.urlPrefixField];
  y -= row;

  // Use HTTPS
  self.useHTTPSCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(fieldX, y, fieldWidth, 18)];
  self.useHTTPSCheckbox.title = @"Use HTTPS";
  [self.useHTTPSCheckbox setButtonType:NSButtonTypeSwitch];
  self.useHTTPSCheckbox.state = NSControlStateValueOn;
  [self.contentView addSubview:self.useHTTPSCheckbox];
  y -= row;

  // Short links
  self.shortLinkCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(fieldX, y, fieldWidth, 18)];
  self.shortLinkCheckbox.title = @"Enable s.ee short links for this host";
  [self.shortLinkCheckbox setButtonType:NSButtonTypeSwitch];
  self.shortLinkCheckbox.target = self;
  self.shortLinkCheckbox.action = @selector(shortLinkChanged:);
  [self.contentView addSubview:self.shortLinkCheckbox];
  y -= 18;

  CGFloat noteY = y - 10; // add gap between checkbox and note
  self.shortLinkNoteLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(fieldX + 19, noteY, fieldWidth - 19, 24)];
  self.shortLinkNoteLabel.font = [NSFont systemFontOfSize:11];
  self.shortLinkNoteLabel.textColor = [NSColor tertiaryLabelColor];
  self.shortLinkNoteLabel.bezeled = NO;
  self.shortLinkNoteLabel.drawsBackground = NO;
  self.shortLinkNoteLabel.editable = NO;
  self.shortLinkNoteLabel.selectable = NO;
  [self.contentView addSubview:self.shortLinkNoteLabel];
  y = noteY - row;

  // Save Path
  self.savePathLabel = [self addLabel:@"Save Path:" atY:y];
  self.saveKeyPathField = [self createTextFieldAtX:fieldX y:y width:fieldWidth];
  self.saveKeyPathField.placeholderString = @"{filename}.{ext}";
  self.saveKeyPathField.delegate = self;
  [self.contentView addSubview:self.saveKeyPathField];
  y -= 18;

  self.pathHintLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(fieldX, y, fieldWidth, 12)];
  self.pathHintLabel.stringValue = @"{year} {month} {day} {filename} {ext} {random} {uuid}";
  self.pathHintLabel.font = [NSFont systemFontOfSize:9];
  self.pathHintLabel.textColor = [NSColor tertiaryLabelColor];
  self.pathHintLabel.bezeled = NO;
  self.pathHintLabel.drawsBackground = NO;
  self.pathHintLabel.editable = NO;
  [self.contentView addSubview:self.pathHintLabel];
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

  // Capture baseline frames for dynamic layout adjustments
  self.baseTokenLabelFrame = self.tokenLabel.frame;
  self.baseTokenFieldFrame = self.tokenField.frame;
  self.baseShortLinkCheckboxFrame = self.shortLinkCheckbox.frame;
  self.baseShortLinkNoteFrame = self.shortLinkNoteLabel.frame;
  self.baseSavePathLabelFrame = self.savePathLabel.frame;
  self.baseSaveKeyPathFieldFrame = self.saveKeyPathField.frame;
  self.basePathHintFrame = self.pathHintLabel.frame;
  self.baseStatusLabelFrame = self.statusLabel.frame;
  self.baseSaveButtonFrame = self.saveButton.frame;
  self.baseValidateButtonFrame = self.validateButton.frame;
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
  self.tokenField.stringValue = self.config.smmsToken ?: @"";
  self.urlPrefixField.stringValue = self.config.urlPrefix ?: @"";
  self.saveKeyPathField.stringValue =
      self.config.saveKeyPath ?: @"{year}/{month}/{day}/{filename}.{ext}";
  self.useHTTPSCheckbox.state = self.config.useHTTPS ? NSControlStateValueOn : NSControlStateValueOff;

  self.shortLinkCheckbox.state = self.config.shortLinkEnabled ? NSControlStateValueOn : NSControlStateValueOff;
  [self updateShortLinkNote];

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
  [self updateEndpointPlaceholder:self.config.providerType];
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
  [self updateEndpointPlaceholder:provider];

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
  case MSTS3ProviderTypeMinIO:
    iconName = @"minio";
    break;
  case MSTS3ProviderTypeSMMS:
    iconName = @"sm.ms";
    break;
  case MSTS3ProviderTypeCustom:
  default:
    iconName = @"custom";
    break;
  }
  self.providerIconView.image = [NSImage imageNamed:iconName];
}

- (void)updateEndpointPlaceholder:(MSTS3ProviderType)provider {
  NSString *placeholder;
  switch (provider) {
  case MSTS3ProviderTypeWasabi:
    placeholder = @"s3.us-east-1.wasabisys.com";
    break;
  case MSTS3ProviderTypeCloudflareR2:
    placeholder = @"<account-id>.r2.cloudflarestorage.com";
    break;
  case MSTS3ProviderTypeBackblazeB2:
    placeholder = @"s3.us-west-004.backblazeb2.com";
    break;
  case MSTS3ProviderTypeMinIO:
    placeholder = @"minio.example.com:9000";
    break;
  case MSTS3ProviderTypeCustom:
    placeholder = @"s3.example.com";
    break;
  case MSTS3ProviderTypeSMMS:
    placeholder = @"";
    break;
  default:
    placeholder = @"";
    break;
  }
  self.endpointField.placeholderString = placeholder;
}

- (void)updateShortLinkNote {
  NSString *apiKey = [MSTConfigManager sharedManager].shortLinkAPIKey;
  if (apiKey.length == 0) {
    self.shortLinkCheckbox.enabled = NO;
    self.shortLinkNoteLabel.stringValue = @"Set s.ee API key in General to enable short links.";
    self.shortLinkNoteLabel.textColor = [NSColor systemOrangeColor];
  } else {
    self.shortLinkCheckbox.enabled = YES;
    self.shortLinkNoteLabel.stringValue = @"Uses default s.ee domain from General settings.";
    self.shortLinkNoteLabel.textColor = [NSColor tertiaryLabelColor];
  }
}

- (void)updateRegionsForProvider:(MSTS3ProviderType)provider {
  [self.regionPopup removeAllItems];
  NSArray *regions = [MSTS3Region regionsForProvider:provider];
  for (MSTS3Region *region in regions) {
    [self.regionPopup addItemWithTitle:region.displayName];
    self.regionPopup.lastItem.representedObject = region.identifier;
  }

  if (regions.count == 0) {
    [self.regionPopup addItemWithTitle:@"N/A"];
    self.regionPopup.lastItem.representedObject = @"";
  }
}

- (void)updateFieldVisibility {
  MSTS3ProviderType provider =
      (MSTS3ProviderType)self.providerPopup.selectedItem.tag;
  BOOL isSMMS = (provider == MSTS3ProviderTypeSMMS);
  BOOL needsEndpoint =
      (provider != MSTS3ProviderTypeAmazonS3 && provider != MSTS3ProviderTypeSMMS);
  BOOL needsRegion = (provider == MSTS3ProviderTypeAmazonS3);

  self.regionLabel.hidden = !needsRegion;
  self.regionPopup.hidden = !needsRegion;
  self.endpointLabel.hidden = !needsEndpoint;
  self.endpointField.hidden = !needsEndpoint;

  self.tokenLabel.hidden = !isSMMS;
  self.tokenField.hidden = !isSMMS;

  NSArray<NSView *> *smmsHiddenViews = @[ self.bucketLabel ?: [[NSView alloc] init],
                                          self.bucketField ?: [[NSView alloc] init],
                                          self.accessKeyLabel ?: [[NSView alloc] init],
                                          self.accessKeyField ?: [[NSView alloc] init],
                                          self.secretKeyLabel ?: [[NSView alloc] init],
                                          self.secretKeyField ?: [[NSView alloc] init],
                                          self.showAccessKeyButton ?: [[NSView alloc] init],
                                          self.showSecretKeyButton ?: [[NSView alloc] init],
                                          self.aclLabel ?: [[NSView alloc] init],
                                          self.aclPopup ?: [[NSView alloc] init],
                                          self.urlPrefixLabel ?: [[NSView alloc] init],
                                          self.urlPrefixField ?: [[NSView alloc] init],
                                          self.useHTTPSCheckbox ?: [[NSView alloc] init],
                                          self.savePathLabel ?: [[NSView alloc] init],
                                          self.saveKeyPathField ?: [[NSView alloc] init],
                                          self.pathHintLabel ?: [[NSView alloc] init] ];

  for (NSView *view in smmsHiddenViews) {
    view.hidden = isSMMS;
    if ([view respondsToSelector:@selector(setEnabled:)]) {
      [(id)view setEnabled:!isSMMS];
    }
  }

  CGFloat rowHeight = 30.0;
  CGFloat collapseOffset = rowHeight * 7; // endpoint, bucket, access, secret, ACL, urlPrefix, useHTTPS

  if (isSMMS) {
    // Move token up to the Region row position
    NSRect regionLabelFrame = self.regionLabel.frame;
    NSRect regionFieldFrame = self.regionPopup.frame;
    self.tokenLabel.frame = (NSRect){.origin = regionLabelFrame.origin, .size = self.tokenLabel.frame.size};
    self.tokenField.frame = (NSRect){.origin = regionFieldFrame.origin, .size = self.tokenField.frame.size};

    // Pull up lower sections to close gaps
    self.shortLinkCheckbox.frame = NSOffsetRect(self.baseShortLinkCheckboxFrame, 0, collapseOffset);
    self.shortLinkNoteLabel.frame = NSOffsetRect(self.baseShortLinkNoteFrame, 0, collapseOffset);
    self.savePathLabel.frame = NSOffsetRect(self.baseSavePathLabelFrame, 0, collapseOffset);
    self.saveKeyPathField.frame = NSOffsetRect(self.baseSaveKeyPathFieldFrame, 0, collapseOffset);
    self.pathHintLabel.frame = NSOffsetRect(self.basePathHintFrame, 0, collapseOffset);
    self.statusLabel.frame = NSOffsetRect(self.baseStatusLabelFrame, 0, collapseOffset);
    self.saveButton.frame = NSOffsetRect(self.baseSaveButtonFrame, 0, collapseOffset);
    self.validateButton.frame = NSOffsetRect(self.baseValidateButtonFrame, 0, collapseOffset);
  } else {
    // Restore original frames for non-SMMS providers
    self.tokenLabel.frame = self.baseTokenLabelFrame;
    self.tokenField.frame = self.baseTokenFieldFrame;
    self.shortLinkCheckbox.frame = self.baseShortLinkCheckboxFrame;
    self.shortLinkNoteLabel.frame = self.baseShortLinkNoteFrame;
    self.savePathLabel.frame = self.baseSavePathLabelFrame;
    self.saveKeyPathField.frame = self.baseSaveKeyPathFieldFrame;
    self.pathHintLabel.frame = self.basePathHintFrame;
    self.statusLabel.frame = self.baseStatusLabelFrame;
    self.saveButton.frame = self.baseSaveButtonFrame;
    self.validateButton.frame = self.baseValidateButtonFrame;
  }

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

- (void)shortLinkChanged:(id)sender {
  BOOL enabled = (self.shortLinkCheckbox.state == NSControlStateValueOn);
  self.config.shortLinkEnabled = enabled;
  [[MSTConfigManager sharedManager] updateHostConfig:self.config];
  [self updateShortLinkNote];
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
  self.config.shortLinkEnabled = (self.shortLinkCheckbox.state == NSControlStateValueOn);

  NSString *savePath = self.saveKeyPathField.stringValue;
  self.config.saveKeyPath =
      savePath.length > 0 ? savePath : @"{filename}.{ext}";

  if (self.config.providerType == MSTS3ProviderTypeSMMS) {
    self.config.smmsToken = self.tokenField.stringValue;
  } else {
    NSMenuItem *regionItem = self.regionPopup.selectedItem;
    NSString *regionValue = regionItem ? (regionItem.representedObject ?: @"") : @"";
    self.config.region = regionValue;
    self.config.endpoint = MSTStripWhitespaceAndNewlines(self.endpointField.stringValue);
    self.config.bucket = self.bucketField.stringValue;
    self.config.accessKey = MSTStripWhitespaceAndNewlines(self.accessKeyField.stringValue);
    self.config.secretKey = MSTStripWhitespaceAndNewlines(self.secretKeyField.stringValue);
    self.config.acl = self.aclPopup.selectedItem.representedObject;
    self.config.urlPrefix = MSTStripWhitespaceAndNewlines(self.urlPrefixField.stringValue);
    self.config.useHTTPS = (self.useHTTPSCheckbox.state == NSControlStateValueOn);
    self.config.smmsToken = @"";
  }

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
  if (testConfig.providerType == MSTS3ProviderTypeSMMS) {
    testConfig.smmsToken = self.tokenField.stringValue;
  } else {
    NSMenuItem *regionItem = self.regionPopup.selectedItem;
    NSString *regionValue = regionItem ? (regionItem.representedObject ?: @"") : @"";
    testConfig.region = regionValue;
    testConfig.endpoint = MSTStripWhitespaceAndNewlines(self.endpointField.stringValue);
    testConfig.bucket = self.bucketField.stringValue;
    testConfig.accessKey = MSTStripWhitespaceAndNewlines(self.accessKeyField.stringValue);
    testConfig.secretKey = MSTStripWhitespaceAndNewlines(self.secretKeyField.stringValue);
    testConfig.acl = self.aclPopup.selectedItem.representedObject;
    testConfig.urlPrefix = MSTStripWhitespaceAndNewlines(self.urlPrefixField.stringValue);
    testConfig.useHTTPS = (self.useHTTPSCheckbox.state == NSControlStateValueOn);
  }

  // Create a minimal 1x1 pixel red PNG image for validation
  // This ensures compatibility with image-only services like SM.MS
  static const unsigned char pngData[] = {
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  // PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  // IHDR chunk
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  // 1x1 dimensions
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,  // 8-bit RGB
      0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  // IDAT chunk
      0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,  // Compressed data (red pixel)
      0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x18, 0xDD,
      0x8D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,  // IEND chunk
      0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
  };
  NSData *testData = [NSData dataWithBytes:pngData length:sizeof(pngData)];
  NSString *testFilename =
      [NSString stringWithFormat:@"_mist_test_%ld.png",
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
            NSString *errorMessage = error.localizedDescription ?: @"Unknown error";
            self.statusLabel.stringValue =
                [NSString stringWithFormat:@"Validation failed: %@", errorMessage];
            self.statusLabel.textColor = [NSColor systemRedColor];
          } else {
            self.statusLabel.stringValue = @"Validation successful!";
            self.statusLabel.textColor = [NSColor systemGreenColor];
          }
        });
      }];
}

@end
