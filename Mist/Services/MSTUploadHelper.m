//
//  MSTUploadHelper.m
//  Mist
//
//  Created by Factory Droid.
//

#import "MSTUploadHelper.h"
#import "MSTConfigManager.h"
#import "MSTConstants.h"
#import "MSTS3HostConfig.h"
#import "MSTS3Uploader.h"
#import <AppKit/AppKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NSErrorDomain const MSTUploadHelperErrorDomain = @"MistUploadHelperError";

@implementation MSTUploadHelper

+ (void)uploadFileAtURL:(NSURL *)url
              completion:(MSTUploadHelperCompletion)completion {
  MSTS3HostConfig *config = [MSTConfigManager sharedManager].defaultHost;
  if (!config) {
    [self dispatchCompletion:completion
                   urlString:nil
                       error:[self missingHostError]];
    return;
  }

  [[MSTS3Uploader sharedUploader] uploadFileAtURL:url
                                       withConfig:config
                                         progress:nil
                                       completion:^(NSString *resultURL,
                                                    NSError *error) {
                                         [self dispatchCompletion:completion
                                                        urlString:resultURL
                                                            error:error];
                                       }];
}

+ (void)uploadData:(NSData *)data
            filename:(NSString *)filename
           completion:(MSTUploadHelperCompletion)completion {
  MSTS3HostConfig *config = [MSTConfigManager sharedManager].defaultHost;
  if (!config) {
    [self dispatchCompletion:completion
                   urlString:nil
                       error:[self missingHostError]];
    return;
  }

  [[MSTS3Uploader sharedUploader] uploadData:data
                                    filename:filename
                                  withConfig:config
                                    progress:nil
                                  completion:^(NSString *resultURL,
                                               NSError *error) {
                                    [self dispatchCompletion:completion
                                                   urlString:resultURL
                                                       error:error];
                                  }];
}

+ (void)uploadFromClipboardWithCompletion:
    (MSTUploadHelperCompletion)completion {

  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];

  NSData *imageData = nil;
  NSString *filename = nil;

  if ([pasteboard
          canReadItemWithDataConformingToTypes:@[ NSPasteboardTypePNG ]]) {
    imageData = [pasteboard dataForType:NSPasteboardTypePNG];
    filename = [self defaultClipboardFilename];
  } else if ([pasteboard canReadItemWithDataConformingToTypes:@[
               NSPasteboardTypeTIFF
             ]]) {
    NSData *tiffData = [pasteboard dataForType:NSPasteboardTypeTIFF];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:tiffData];
    imageData = [imageRep representationUsingType:NSBitmapImageFileTypePNG
                                       properties:@{}];
    filename = [self defaultClipboardFilename];
  } else if ([pasteboard canReadItemWithDataConformingToTypes:@[
               NSPasteboardTypeFileURL
             ]]) {
    NSArray *urls = [pasteboard
        readObjectsForClasses:@[ [NSURL class] ]
                      options:@{NSPasteboardURLReadingFileURLsOnlyKey : @YES}];
    if (urls.count > 0) {
      [self uploadFileAtURL:urls.firstObject completion:completion];
      return;
    }
  }

  if (!imageData || !filename) {
    [self dispatchCompletion:completion
                   urlString:nil
                       error:[self emptyClipboardError]];
    return;
  }

  [self uploadData:imageData filename:filename completion:completion];
}

+ (NSError *)missingHostError {
  NSDictionary *userInfo =
      @{NSLocalizedDescriptionKey : @"Please configure a host first."};
  return [NSError errorWithDomain:MSTUploadHelperErrorDomain
                             code:MSTUploadHelperErrorNoHost
                         userInfo:userInfo];
}

+ (NSError *)emptyClipboardError {
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Clipboard is empty."};
  return [NSError errorWithDomain:MSTUploadHelperErrorDomain
                             code:MSTUploadHelperErrorEmptyClipboard
                         userInfo:userInfo];
}

#pragma mark - Helpers

+ (NSString *)defaultClipboardFilename {
  return [NSString stringWithFormat:@"clipboard_%ld.png",
                                    (long)[[NSDate date] timeIntervalSince1970]];
}

+ (void)dispatchCompletion:(MSTUploadHelperCompletion)completion
                 urlString:(NSString *_Nullable)url
                     error:(NSError *_Nullable)error {
  if (!completion) {
    return;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    completion(url, error);
  });
}

@end
