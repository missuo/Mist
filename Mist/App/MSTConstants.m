//
//  MSTConstants.m
//  Mist
//
//  Created by Vincent Yang on 12/13/25.
//

#import "MSTConstants.h"

#pragma mark - UserDefaults Keys

NSString * const kMSTHostConfigs = @"Mist_HostConfigs";
NSString * const kMSTDefaultHostId = @"Mist_DefaultHostId";
NSString * const kMSTOutputFormat = @"Mist_OutputFormat";
NSString * const kMSTCompressFactor = @"Mist_CompressFactor";
NSString * const kMSTRemoveEXIF = @"Mist_RemoveEXIF";
NSString * const kMSTAppGroupIdentifier = @"group.nz.owo.Mist";

#pragma mark - Notifications

NSNotificationName const MSTConfigDidChangeNotification = @"MSTConfigDidChangeNotification";
NSNotificationName const MSTUploadDidStartNotification = @"MSTUploadDidStartNotification";
NSNotificationName const MSTUploadDidFinishNotification = @"MSTUploadDidFinishNotification";
NSNotificationName const MSTUploadDidFailNotification = @"MSTUploadDidFailNotification";
NSNotificationName const MSTUploadProgressNotification = @"MSTUploadProgressNotification";
