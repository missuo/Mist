//
//  MSTUploadHistoryManager.m
//  Mist
//
//  Created by Claude on 12/23/25.
//

#import "MSTUploadHistoryManager.h"
#import "MSTUploadHistoryItem.h"
#import "MSTS3HostConfig.h"
#import "MSTConstants.h"

NSString * const MSTUploadHistoryDidChangeNotification = @"MSTUploadHistoryDidChangeNotification";

static NSString * const kHistoryKey = @"uploadHistory";
static const NSUInteger kMaxHistoryItems = 500;

@interface MSTUploadHistoryManager ()

@property (nonatomic, strong) NSMutableArray<MSTUploadHistoryItem *> *mutableHistoryItems;
@property (nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation MSTUploadHistoryManager

+ (MSTUploadHistoryManager *)sharedManager {
  static MSTUploadHistoryManager *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[MSTUploadHistoryManager alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    NSString *suiteName = kMSTAppGroupIdentifier;
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    _userDefaults = sharedDefaults ?: [NSUserDefaults standardUserDefaults];
    _mutableHistoryItems = [NSMutableArray array];
    [self loadHistory];
  }
  return self;
}

#pragma mark - Properties

- (NSArray<MSTUploadHistoryItem *> *)historyItems {
  return [self.mutableHistoryItems copy];
}

#pragma mark - Public Methods

- (void)addHistoryItemWithFilename:(NSString *)filename
                               url:(NSString *)url
                          shortURL:(nullable NSString *)shortURL
                        hostConfig:(MSTS3HostConfig *)hostConfig
                          fileSize:(NSUInteger)fileSize
                          mimeType:(nullable NSString *)mimeType
                     thumbnailData:(nullable NSData *)thumbnailData {
  MSTUploadHistoryItem *item = [[MSTUploadHistoryItem alloc] init];
  item.filename = filename;
  item.url = url;
  item.shortURL = shortURL;
  item.hostName = hostConfig.name ?: @"Unknown";
  item.hostIdentifier = hostConfig.identifier ?: @"";
  item.uploadDate = [NSDate date];
  item.fileSize = fileSize;
  item.mimeType = mimeType;
  item.thumbnailData = thumbnailData;

  // Insert at the beginning (newest first)
  [self.mutableHistoryItems insertObject:item atIndex:0];

  // Trim to max size
  while (self.mutableHistoryItems.count > kMaxHistoryItems) {
    [self.mutableHistoryItems removeLastObject];
  }

  [self saveHistory];
  [self postChangeNotification];
}

- (void)removeHistoryItem:(MSTUploadHistoryItem *)item {
  [self.mutableHistoryItems removeObject:item];
  [self saveHistory];
  [self postChangeNotification];
}

- (void)removeHistoryItemWithIdentifier:(NSString *)identifier {
  NSUInteger index = [self.mutableHistoryItems indexOfObjectPassingTest:^BOOL(MSTUploadHistoryItem *item, NSUInteger idx, BOOL *stop) {
    return [item.identifier isEqualToString:identifier];
  }];

  if (index != NSNotFound) {
    [self.mutableHistoryItems removeObjectAtIndex:index];
    [self saveHistory];
    [self postChangeNotification];
  }
}

- (void)clearAllHistory {
  [self.mutableHistoryItems removeAllObjects];
  [self saveHistory];
  [self postChangeNotification];
}

#pragma mark - Persistence

- (void)saveHistory {
  NSError *error = nil;
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.mutableHistoryItems
                                       requiringSecureCoding:YES
                                                       error:&error];
  if (error) {
    NSLog(@"[History] Failed to archive history: %@", error);
    return;
  }

  [self.userDefaults setObject:data forKey:kHistoryKey];
  [self.userDefaults synchronize];
}

- (void)loadHistory {
  NSData *data = [self.userDefaults objectForKey:kHistoryKey];
  if (!data) {
    return;
  }

  NSError *error = nil;
  NSSet *classes = [NSSet setWithObjects:[NSMutableArray class], [MSTUploadHistoryItem class], nil];
  NSMutableArray *items = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                              fromData:data
                                                                 error:&error];
  if (error) {
    NSLog(@"[History] Failed to unarchive history: %@", error);
    return;
  }

  if (items) {
    self.mutableHistoryItems = items;
  }
}

#pragma mark - Private

- (void)postChangeNotification {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:MSTUploadHistoryDidChangeNotification
                                                        object:self];
  });
}

@end
