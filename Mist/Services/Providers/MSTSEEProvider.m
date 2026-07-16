//
//  MSTSEEProvider.m
//  Mist
//
//  Created by Vincent Yang on 12/15/25.
//

#import "MSTSEEProvider.h"
#import "MSTS3HostConfig.h"
#import "MSTUploadUtilities.h"

@implementation MSTSEEProvider

+ (NSString *)providerName {
  return @"S.EE";
}

#pragma mark - MSTUploadProvider

- (BOOL)validateConfig:(MSTS3HostConfig *)config error:(NSError **)error {
  if (config.seeToken.length == 0) {
    if (error) {
      *error = [NSError
          errorWithDomain:@"MSTUploaderError"
                     code:-4
                 userInfo:@{NSLocalizedDescriptionKey : @"Invalid S.EE token"}];
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

  NSURL *url = [NSURL URLWithString:@"https://s.ee/api/v1/file/upload"];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  request.HTTPMethod = @"POST";
  [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@",
                                               boundary]
      forHTTPHeaderField:@"Content-Type"];
  [request setValue:config.seeToken forHTTPHeaderField:@"Authorization"];

  NSMutableData *body = [NSMutableData data];
  NSString *lineBreak = @"\r\n";
  [body appendData:[[NSString stringWithFormat:@"--%@%@", boundary, lineBreak]
                        dataUsingEncoding:NSUTF8StringEncoding]];
  NSString *disposition =
      [NSString stringWithFormat:
                    @"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"%@",
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

                     NSError *parseError = nil;
                     NSString *urlString =
                         [self parseSEEDirectURLFromResponse:responseData
                                                       error:&parseError];

                     if (!urlString) {
                       NSError *finalError = parseError ?: [NSError
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

- (nullable NSString *)parseSEEDirectURLFromResponse:(NSData *)responseData
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
  NSNumber *codeValue = json[@"code"];
  BOOL success = (!codeValue || codeValue.integerValue == 0 ||
                  codeValue.integerValue == 200);

  if (!success) {
    NSString *message =
        [json[@"message"] isKindOfClass:[NSString class]] ? json[@"message"]
                                                          : @"Upload failed";
    if (error) {
      *error = [NSError errorWithDomain:@"MSTUploaderError"
                                   code:codeValue.integerValue
                               userInfo:@{NSLocalizedDescriptionKey : message}];
    }
    return nil;
  }

  id data = json[@"data"];
  if (![data isKindOfClass:[NSDictionary class]]) {
    if (error) {
      *error = [NSError errorWithDomain:@"MSTUploaderError"
                                   code:-8
                               userInfo:@{NSLocalizedDescriptionKey : @"Invalid S.EE response"}];
    }
    return nil;
  }

  NSString *directURL = ((NSDictionary *)data)[@"url"];
  if ([directURL isKindOfClass:[NSString class]] && directURL.length > 0) {
    return directURL;
  }

  if (error) {
    *error = [NSError errorWithDomain:@"MSTUploaderError"
                                 code:-8
                             userInfo:@{NSLocalizedDescriptionKey : @"Invalid S.EE response"}];
  }
  return nil;
}

@end
