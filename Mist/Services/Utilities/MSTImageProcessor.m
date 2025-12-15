//
//  MSTImageProcessor.m
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import "MSTImageProcessor.h"
#import "MSTConfigManager.h"
#import <AppKit/AppKit.h>

@implementation MSTImageProcessor

+ (BOOL)isImageFile:(NSString *)filename {
  NSString *ext = [[filename pathExtension] lowercaseString];
  NSSet *imageExtensions = [NSSet setWithArray:@[
    @"jpg", @"jpeg", @"png", @"gif", @"bmp", @"tiff", @"tif",
    @"heic", @"heif", @"webp", @"ico"
  ]];
  return [imageExtensions containsObject:ext];
}

+ (NSData *)processImageDataIfNeeded:(NSData *)data filename:(NSString *)filename {
  if (![self isImageFile:filename]) {
    return data;
  }

  MSTConfigManager *config = [MSTConfigManager sharedManager];
  BOOL shouldCompress = config.compressFactor > 0;
  BOOL shouldRemoveEXIF = config.removeEXIF;

  if (!shouldCompress && !shouldRemoveEXIF) {
    return data;
  }

  NSImage *image = [[NSImage alloc] initWithData:data];
  if (!image || image.representations.count == 0) {
    NSLog(@"[Mist] Failed to load image, skipping processing");
    return data;
  }

  // Get the first representation
  NSImageRep *imageRep = image.representations.firstObject;
  NSBitmapImageRep *bitmapRep = nil;

  if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
    bitmapRep = (NSBitmapImageRep *)imageRep;
  } else {
    // Convert to bitmap representation
    NSSize imageSize = image.size;
    bitmapRep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:imageSize.width
                      pixelsHigh:imageSize.height
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                     bytesPerRow:0
                    bitsPerPixel:0];

    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmapRep];
    [NSGraphicsContext setCurrentContext:context];
    [image drawInRect:NSMakeRect(0, 0, imageSize.width, imageSize.height)];
    [NSGraphicsContext restoreGraphicsState];
  }

  // Determine output format based on file extension
  NSString *ext = [[filename pathExtension] lowercaseString];
  NSBitmapImageFileType fileType = NSBitmapImageFileTypePNG;

  if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) {
    fileType = NSBitmapImageFileTypeJPEG;
  } else if ([ext isEqualToString:@"png"]) {
    fileType = NSBitmapImageFileTypePNG;
  } else if ([ext isEqualToString:@"gif"]) {
    fileType = NSBitmapImageFileTypeGIF;
  } else if ([ext isEqualToString:@"bmp"]) {
    fileType = NSBitmapImageFileTypeBMP;
  } else if ([ext isEqualToString:@"tiff"] || [ext isEqualToString:@"tif"]) {
    fileType = NSBitmapImageFileTypeTIFF;
  } else {
    // Default to PNG for unknown formats
    fileType = NSBitmapImageFileTypePNG;
  }

  // Build properties dictionary
  NSMutableDictionary *properties = [NSMutableDictionary dictionary];

  // Apply compression if enabled
  if (shouldCompress && config.compressFactor >= 10 && config.compressFactor <= 90) {
    CGFloat compressionFactor = config.compressFactor / 100.0;
    properties[NSImageCompressionFactor] = @(compressionFactor);
    NSLog(@"[Mist] Compressing image with quality: %ld%%", (long)config.compressFactor);
  }

  // Remove EXIF if requested
  if (shouldRemoveEXIF) {
    // By not including existing properties, EXIF data will be stripped
    properties[NSImageEXIFData] = [NSData data]; // Empty EXIF
    NSLog(@"[Mist] Removing EXIF data from image");
  }

  NSData *processedData = [bitmapRep representationUsingType:fileType
                                                  properties:properties];

  if (processedData) {
    NSLog(@"[Mist] Image processing complete. Original: %lu bytes, Processed: %lu bytes",
          (unsigned long)data.length, (unsigned long)processedData.length);
    return processedData;
  } else {
    NSLog(@"[Mist] Image processing failed, using original data");
    return data;
  }
}

@end
