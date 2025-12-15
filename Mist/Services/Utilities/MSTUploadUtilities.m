//
//  MSTUploadUtilities.m
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import "MSTUploadUtilities.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation MSTUploadUtilities

+ (NSString *)uriEncode:(NSString *)string encodeSlash:(BOOL)encodeSlash {
  NSMutableCharacterSet *allowed =
      [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
  [allowed addCharactersInString:@"-._~"];
  if (!encodeSlash) {
    [allowed addCharactersInString:@"/"];
  }
  return [string stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

+ (NSString *)mimeTypeForFilename:(NSString *)filename {
  NSString *ext = [filename pathExtension].lowercaseString;

  if (@available(macOS 11.0, *)) {
    UTType *type = [UTType typeWithFilenameExtension:ext];
    if (type.preferredMIMEType) {
      return type.preferredMIMEType;
    }
  }

  // Fallback for common types
  NSDictionary *mimeTypes = @{
    @"png" : @"image/png",
    @"jpg" : @"image/jpeg",
    @"jpeg" : @"image/jpeg",
    @"gif" : @"image/gif",
    @"bmp" : @"image/bmp",
    @"webp" : @"image/webp",
    @"svg" : @"image/svg+xml",
    @"ico" : @"image/x-icon",
    @"tiff" : @"image/tiff",
    @"tif" : @"image/tiff",
    @"heic" : @"image/heic",
    @"heif" : @"image/heif",
    @"pdf" : @"application/pdf",
    @"mp4" : @"video/mp4",
    @"mov" : @"video/quicktime",
    @"avi" : @"video/x-msvideo",
    @"zip" : @"application/zip",
    @"json" : @"application/json",
    @"xml" : @"application/xml",
    @"txt" : @"text/plain",
    @"html" : @"text/html",
    @"css" : @"text/css",
    @"js" : @"application/javascript"
  };

  return mimeTypes[ext] ?: @"application/octet-stream";
}

+ (NSString *)generateSaveKeyWithTemplate:(NSString *)templateString
                                 filename:(NSString *)filename {
  NSDate *now = [NSDate date];
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *components =
      [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth |
                            NSCalendarUnitDay | NSCalendarUnitHour |
                            NSCalendarUnitMinute | NSCalendarUnitSecond)
                  fromDate:now];

  NSString *name = [filename stringByDeletingPathExtension];
  NSString *ext = [filename pathExtension];
  NSString *timestamp =
      [NSString stringWithFormat:@"%ld", (long)[now timeIntervalSince1970]];
  NSString *uuid = [[[NSUUID UUID] UUIDString] lowercaseString];
  NSString *random = [uuid substringToIndex:8];

  NSString *result = templateString;
  result = [result
      stringByReplacingOccurrencesOfString:@"{year}"
                                withString:[NSString
                                               stringWithFormat:@"%04ld",
                                                                (long)components
                                                                    .year]];
  result = [result
      stringByReplacingOccurrencesOfString:@"{month}"
                                withString:[NSString
                                               stringWithFormat:@"%02ld",
                                                                (long)components
                                                                    .month]];
  result = [result
      stringByReplacingOccurrencesOfString:@"{day}"
                                withString:[NSString
                                               stringWithFormat:@"%02ld",
                                                                (long)components
                                                                    .day]];
  result = [result
      stringByReplacingOccurrencesOfString:@"{hour}"
                                withString:[NSString
                                               stringWithFormat:@"%02ld",
                                                                (long)components
                                                                    .hour]];
  result = [result
      stringByReplacingOccurrencesOfString:@"{minute}"
                                withString:[NSString
                                               stringWithFormat:@"%02ld",
                                                                (long)components
                                                                    .minute]];
  result = [result
      stringByReplacingOccurrencesOfString:@"{second}"
                                withString:[NSString
                                               stringWithFormat:@"%02ld",
                                                                (long)components
                                                                    .second]];
  result = [result stringByReplacingOccurrencesOfString:@"{timestamp}"
                                             withString:timestamp];
  result = [result stringByReplacingOccurrencesOfString:@"{filename}"
                                             withString:name];
  result = [result stringByReplacingOccurrencesOfString:@"{ext}"
                                             withString:ext];
  result = [result stringByReplacingOccurrencesOfString:@"{random}"
                                             withString:random];
  result = [result stringByReplacingOccurrencesOfString:@"{uuid}"
                                             withString:uuid];

  return result;
}

+ (nullable NSString *)extractRegionFromB2Endpoint:(NSString *)host {
  // B2 endpoint format: s3.{region}.backblazeb2.com
  // Example: s3.us-west-004.backblazeb2.com -> us-west-004
  if (!host || host.length == 0) {
    return nil;
  }

  NSArray *components = [host componentsSeparatedByString:@"."];
  // Expected: ["s3", "us-west-004", "backblazeb2", "com"]
  if (components.count >= 4 && [components[0] isEqualToString:@"s3"] &&
      [components[components.count - 2] isEqualToString:@"backblazeb2"]) {
    return components[1];
  }

  return nil;
}

@end
