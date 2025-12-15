//
//  MSTSMSProvider.m
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import "MSTSMSProvider.h"
#import "MSTS3HostConfig.h"
#import "MSTUploadUtilities.h"

@implementation MSTSMSProvider

+ (NSString *)providerName {
  return @"SM.MS";
}

#pragma mark - MSTUploadProvider

- (BOOL)validateConfig:(MSTS3HostConfig *)config error:(NSError **)error {
  if (config.smmsToken.length == 0) {
    if (error) {
      *error = [NSError
          errorWithDomain:@"MSTUploaderError"
                     code:-4
                 userInfo:@{NSLocalizedDescriptionKey : @"Invalid SM.MS token"}];
    }
    return NO;
  }
  return YES;
}

- (void)uploadData:(NSData *)data
          filename:(NSString *)filename
        withConfig:(MSTS3HostConfig *)config
           session:(NSURLSession *)session
          progress:(MSTProviderProgressBlock)progressBlock
        completion:(MSTProviderCompletionBlock)completion {

  NSString *mimeType = [MSTUploadUtilities mimeTypeForFilename:filename];
  NSString *boundary = [NSString stringWithFormat:@"Boundary-%@",
                                                  [[NSUUID UUID] UUIDString]];

  NSURL *url = [NSURL URLWithString:@"https://smms.app/api/v2/upload"];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  request.HTTPMethod = @"POST";
  [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@",
                                               boundary]
      forHTTPHeaderField:@"Content-Type"];
  [request setValue:@"https://sm.ms/" forHTTPHeaderField:@"referer"];
  [request setValue:@"https://sm.ms" forHTTPHeaderField:@"origin"];
  [request setValue:config.smmsToken forHTTPHeaderField:@"Authorization"];

  NSMutableData *body = [NSMutableData data];
  NSString *lineBreak = @"\r\n";
  [body appendData:[[NSString stringWithFormat:@"--%@%@", boundary, lineBreak]
                        dataUsingEncoding:NSUTF8StringEncoding]];
  NSString *disposition =
      [NSString stringWithFormat:
                    @"Content-Disposition: form-data; name=\"smfile\"; filename=\"%@\"%@",
                    filename, lineBreak];
  [body appendData:[disposition dataUsingEncoding:NSUTF8StringEncoding]];
  NSString *typeLine =
      [NSString stringWithFormat:@"Content-Type: %@%@%@", mimeType, lineBreak,
                                 lineBreak];
  [body appendData:[typeLine dataUsingEncoding:NSUTF8StringEncoding]];
  [body appendData:data];
  [body appendData:[lineBreak dataUsingEncoding:NSUTF8StringEncoding]];
  [body appendData:[[NSString stringWithFormat:@"--%@--%@", boundary, lineBreak]
                        dataUsingEncoding:NSUTF8StringEncoding]];

  NSURLSessionUploadTask *task =
      [session uploadTaskWithRequest:request
                            fromData:body
                   completionHandler:^(NSData *_Nullable responseData,
                                       NSURLResponse *_Nullable response,
                                       NSError *_Nullable error) {
                     if (error) {
                       completion(nil, error);
                       return;
                     }

                     NSHTTPURLResponse *httpResponse =
                         (NSHTTPURLResponse *)response;
                     if (httpResponse.statusCode < 200 ||
                         httpResponse.statusCode >= 300) {
                       NSString *message = responseData
                                               ? [[NSString alloc]
                                                     initWithData:responseData
                                                         encoding:NSUTF8StringEncoding]
                                               : @"Upload failed";
                       NSError *statusError = [NSError
                           errorWithDomain:@"MSTUploaderError"
                                      code:httpResponse.statusCode
                                  userInfo:@{NSLocalizedDescriptionKey : message ?: @"Upload failed"}];
                       completion(nil, statusError);
                       return;
                     }

                     NSError *jsonError = nil;
                     NSString *urlString =
                         [self parseSmmsURLFromResponse:responseData
                                                  error:&jsonError];

                     if (!urlString) {
                       NSError *finalError = jsonError ?: [NSError
                           errorWithDomain:@"MSTUploaderError"
                                      code:-5
                                  userInfo:@{NSLocalizedDescriptionKey : @"Upload failed"}];
                       completion(nil, finalError);
                       return;
                     }

                     completion(urlString, nil);
                   }];

  [task resume];
}

#pragma mark - Response Parsing

- (nullable NSString *)parseSmmsURLFromResponse:(NSData *)responseData
                                          error:(NSError **)error {
  if (!responseData) {
    if (error) {
      *error = [NSError errorWithDomain:@"MSTUploaderError"
                                   code:-6
                               userInfo:@{NSLocalizedDescriptionKey : @"Empty response"}];
    }
    return nil;
  }

  id jsonObj = [NSJSONSerialization JSONObjectWithData:responseData
                                               options:0
                                                 error:error];
  if (!jsonObj || ![jsonObj isKindOfClass:[NSDictionary class]]) {
    return nil;
  }

  NSDictionary *json = (NSDictionary *)jsonObj;
  BOOL success = [json[@"success"] boolValue] || [json[@"success"] intValue] == 1;

  if (!success) {
    NSString *code = [json[@"code"] isKindOfClass:[NSString class]] ? json[@"code"] : @"";
    if ([code isEqualToString:@"image_repeated"]) {
      NSString *repeatedURL = [json[@"images"] isKindOfClass:[NSString class]] ? json[@"images"] : nil;
      if (repeatedURL.length > 0) {
        return repeatedURL;
      }
    }

    NSString *message =
        [json[@"message"] isKindOfClass:[NSString class]] ? json[@"message"]
                                                         : @"Upload failed";
    if (error) {
      *error = [NSError errorWithDomain:@"MSTUploaderError"
                                   code:-7
                               userInfo:@{NSLocalizedDescriptionKey : message}];
    }
    return nil;
  }

  id data = json[@"data"];
  NSString *url = nil;
  if ([data isKindOfClass:[NSDictionary class]]) {
    url = ((NSDictionary *)data)[@"url"];
  }
  if ([url isKindOfClass:[NSString class]] && url.length > 0) {
    return url;
  }

  if (error) {
    *error = [NSError errorWithDomain:@"MSTUploaderError"
                                 code:-8
                             userInfo:@{NSLocalizedDescriptionKey : @"Invalid SM.MS response"}];
  }
  return nil;
}

@end
