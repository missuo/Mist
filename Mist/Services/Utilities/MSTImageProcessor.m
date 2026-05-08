//
//  MSTImageProcessor.m
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import "MSTImageProcessor.h"
#import "MSTConfigManager.h"
#import <AppKit/AppKit.h>
#import <ImageIO/ImageIO.h>

@implementation MSTImageProcessor

+ (BOOL)isImageFile:(NSString *)filename {
  NSString *ext = [[filename pathExtension] lowercaseString];
  static NSSet *imageExtensions = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    imageExtensions = [NSSet setWithArray:@[
      @"jpg", @"jpeg", @"png", @"gif", @"bmp", @"tiff", @"tif",
      @"heic", @"heif", @"webp", @"ico", @"avif"
    ]];
  });
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

  // Determine output format based on file extension and system capabilities
  NSString *ext = [[filename pathExtension] lowercaseString];
  NSBitmapImageFileType fileType = NSBitmapImageFileTypePNG;
  NSString *uti = nil;
  BOOL useImageIO = NO;

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
  } else if ([ext isEqualToString:@"webp"]) {
    if (@available(macOS 11.0, *)) {
      // 6 is the value for WebP in NSBitmapImageFileType on macOS 11+
      fileType = (NSBitmapImageFileType)6; 
    } else {
      fileType = NSBitmapImageFileTypePNG;
    }
  } else if ([ext isEqualToString:@"heic"] || [ext isEqualToString:@"heif"]) {
    if (@available(macOS 10.13, *)) {
      useImageIO = YES;
      uti = @"public.heic";
    } else {
      fileType = NSBitmapImageFileTypePNG;
    }
  } else if ([ext isEqualToString:@"avif"]) {
    if (@available(macOS 13.0, *)) {
      useImageIO = YES;
      uti = @"public.avif";
    } else {
      fileType = NSBitmapImageFileTypePNG;
    }
  } else {
    // Default to PNG for unknown formats
    fileType = NSBitmapImageFileTypePNG;
  }

  NSData *processedData = nil;
  CGFloat compressionFactor = config.compressFactor / 100.0;
  BOOL applyCompression = (shouldCompress && config.compressFactor >= 10 && config.compressFactor <= 90);

  if (useImageIO && uti) {
    NSMutableData *outputData = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)outputData, (__bridge CFStringRef)uti, 1, NULL);
    if (dest) {
      NSMutableDictionary *options = [NSMutableDictionary dictionary];
      if (applyCompression) {
        options[(__bridge NSString *)kCGImageDestinationLossyCompressionQuality] = @(compressionFactor);
        NSLog(@"[Mist] Compressing %s with quality: %ld%%", uti.UTF8String, (long)config.compressFactor);
      }
      
      // By default, ImageIO strips metadata unless we explicitly add it.
      // So not providing kCGImageDestinationMetadata effectively removes EXIF.

      CGImageRef cgImage = [bitmapRep CGImage];
      CGImageDestinationAddImage(dest, cgImage, (__bridge CFDictionaryRef)options);
      if (CGImageDestinationFinalize(dest)) {
        processedData = outputData;
      }
      CFRelease(dest);
    }
  }

  if (!processedData) {
    // Fallback to AppKit (NSBitmapImageRep) for traditional formats or old systems
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];

    if (applyCompression) {
      properties[NSImageCompressionFactor] = @(compressionFactor);
      NSLog(@"[Mist] AppKit Path: Compressing image with quality: %ld%%", (long)config.compressFactor);
    }

    if (shouldRemoveEXIF) {
      properties[NSImageEXIFData] = [NSData data]; // Empty EXIF
      NSLog(@"[Mist] AppKit Path: Removing EXIF data from image");
    }

    processedData = [bitmapRep representationUsingType:fileType properties:properties];
  }

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
