//
//  MSTUploadHistoryItem.m
//  Mist
//
//  Created by Claude on 12/23/25.
//

#import "MSTUploadHistoryItem.h"

@implementation MSTUploadHistoryItem

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)init {
  return [self initWithIdentifier:[[NSUUID UUID] UUIDString]];
}

- (instancetype)initWithIdentifier:(NSString *)identifier {
  self = [super init];
  if (self) {
    _identifier = [identifier copy];
    _filename = @"";
    _url = @"";
    _hostName = @"";
    _hostIdentifier = @"";
    _uploadDate = [NSDate date];
    _fileSize = 0;
  }
  return self;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:_identifier forKey:@"identifier"];
  [coder encodeObject:_filename forKey:@"filename"];
  [coder encodeObject:_url forKey:@"url"];
  [coder encodeObject:_shortURL forKey:@"shortURL"];
  [coder encodeObject:_hostName forKey:@"hostName"];
  [coder encodeObject:_hostIdentifier forKey:@"hostIdentifier"];
  [coder encodeObject:_uploadDate forKey:@"uploadDate"];
  [coder encodeInteger:_fileSize forKey:@"fileSize"];
  [coder encodeObject:_mimeType forKey:@"mimeType"];
  [coder encodeObject:_thumbnailData forKey:@"thumbnailData"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
  self = [self initWithIdentifier:identifier ?: [[NSUUID UUID] UUIDString]];
  if (self) {
    _filename = [coder decodeObjectOfClass:[NSString class] forKey:@"filename"] ?: @"";
    _url = [coder decodeObjectOfClass:[NSString class] forKey:@"url"] ?: @"";
    _shortURL = [coder decodeObjectOfClass:[NSString class] forKey:@"shortURL"];
    _hostName = [coder decodeObjectOfClass:[NSString class] forKey:@"hostName"] ?: @"";
    _hostIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"hostIdentifier"] ?: @"";
    _uploadDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"uploadDate"] ?: [NSDate date];
    _fileSize = [coder decodeIntegerForKey:@"fileSize"];
    _mimeType = [coder decodeObjectOfClass:[NSString class] forKey:@"mimeType"];
    _thumbnailData = [coder decodeObjectOfClass:[NSData class] forKey:@"thumbnailData"];
  }
  return self;
}

@end
