//
//  MSTShortLinkService.m
//  Mist
//
//  Created by Vincent Yang on 12/14/25.
//

#import "MSTShortLinkService.h"

static NSString * const kMSTShortLinkBaseURL = @"https://s.ee/api/v1";

@implementation MSTShortLinkService

- (void)fetchAvailableDomainsWithAPIKey:(NSString *)apiKey
                               completion:(void (^)(NSArray<NSString *> * _Nullable domains,
                                                    NSError * _Nullable error))completion {
  NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/domains", kMSTShortLinkBaseURL]];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  request.HTTPMethod = @"GET";
  [request setValue:apiKey forHTTPHeaderField:@"Authorization"];

  NSURLSessionDataTask *task = [[NSURLSession sharedSession]
      dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
          NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
          NSString *bodyString = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"<no body>";
          if (!error && http.statusCode >= 200 && http.statusCode < 300) {
            NSLog(@"[ShortLink] GET /domains status=%ld body=%@",
                  (long)(http ? http.statusCode : -1),
                  bodyString ?: @"<decode failed>");
          } else {
            NSLog(@"[ShortLink] GET /domains status=%ld error=%@ body=%@",
                  (long)(http ? http.statusCode : -1),
                  error.localizedDescription ?: @"<none>",
                  bodyString ?: @"<decode failed>");
          }

          if (error) {
            [self dispatchCompletion:completion domains:nil error:error];
            return;
          }

          if (http.statusCode < 200 || http.statusCode >= 300) {
            NSError *statusError = [NSError errorWithDomain:@"MSTShortLinkError"
                                                       code:http.statusCode
                                                   userInfo:@{NSLocalizedDescriptionKey : @"Failed to fetch domains"}];
            [self dispatchCompletion:completion domains:nil error:statusError];
            return;
          }

          NSError *jsonError = nil;
          NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
          if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
            [self dispatchCompletion:completion domains:nil error:jsonError];
            return;
          }

          NSNumber *code = json[@"code"];
          BOOL success = (!code || code.integerValue == 0 || code.integerValue == 200);
          if (!success) {
            NSString *message = json[@"message"] ?: @"Unexpected response";
            NSError *apiError = [NSError errorWithDomain:@"MSTShortLinkError"
                                                    code:code.integerValue
                                                userInfo:@{NSLocalizedDescriptionKey : message}];
            [self dispatchCompletion:completion domains:nil error:apiError];
            return;
          }

          NSDictionary *dataDict = json[@"data"];
          NSArray *domains = dataDict[@"domains"];
          if (![domains isKindOfClass:[NSArray class]]) {
            NSError *parseError = [NSError errorWithDomain:@"MSTShortLinkError"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey : @"Invalid domains payload"}];
            [self dispatchCompletion:completion domains:nil error:parseError];
            return;
          }

          NSLog(@"[ShortLink] Domains parsed: %@", domains);
          [self dispatchCompletion:completion domains:domains error:nil];
        }];

  [task resume];
}

- (void)createShortURLForURL:(NSString *)targetURL
                       domain:(NSString *)domain
                        apiKey:(NSString *)apiKey
                    completion:(void (^)(NSString * _Nullable shortURL,
                                         NSError * _Nullable error))completion {
  NSLog(@"[ShortLink] createShortURL called: domain=%@, targetURL=%@, apiKeyLength=%lu",
        domain, targetURL, (unsigned long)apiKey.length);

  NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/shorten", kMSTShortLinkBaseURL]];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  request.HTTPMethod = @"POST";
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [request setValue:apiKey forHTTPHeaderField:@"Authorization"];

  NSDictionary *body = @{ @"domain" : domain ?: @"s.ee",
                          @"target_url" : targetURL ?: @"" };

  NSError *jsonError = nil;
  NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
  if (jsonError) {
    [self dispatchShortenCompletion:completion url:nil error:jsonError];
    return;
  }
  request.HTTPBody = bodyData;

  NSURLSessionDataTask *task = [[NSURLSession sharedSession]
      dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
          NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
          NSString *bodyString = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"<no body>";
          NSLog(@"[ShortLink] POST /shorten status=%ld error=%@ body=%@",
                (long)(http ? http.statusCode : -1),
                error.localizedDescription ?: @"<none>",
                bodyString ?: @"<decode failed>");

          if (error) {
            [self dispatchShortenCompletion:completion url:nil error:error];
            return;
          }

          if (http.statusCode < 200 || http.statusCode >= 300) {
            NSError *statusError = [NSError errorWithDomain:@"MSTShortLinkError"
                                                       code:http.statusCode
                                                   userInfo:@{NSLocalizedDescriptionKey : @"Shorten request failed"}];
            [self dispatchShortenCompletion:completion url:nil error:statusError];
            return;
          }

          NSError *jsonError2 = nil;
          NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError2];
          if (jsonError2 || ![json isKindOfClass:[NSDictionary class]]) {
            [self dispatchShortenCompletion:completion url:nil error:jsonError2];
            return;
          }

          NSNumber *code = json[@"code"];
          BOOL success = (!code || code.integerValue == 0 || code.integerValue == 200);
          if (!success) {
            NSString *message = json[@"message"] ?: @"Unexpected response";
            NSError *apiError = [NSError errorWithDomain:@"MSTShortLinkError"
                                                    code:code.integerValue
                                                userInfo:@{NSLocalizedDescriptionKey : message}];
            [self dispatchShortenCompletion:completion url:nil error:apiError];
            return;
          }

          NSDictionary *dataDict = json[@"data"];
          NSString *shortURL = dataDict[@"short_url"];
          if (![shortURL isKindOfClass:[NSString class]] || shortURL.length == 0) {
            NSError *parseError = [NSError errorWithDomain:@"MSTShortLinkError"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey : @"Invalid short URL"}];
            [self dispatchShortenCompletion:completion url:nil error:parseError];
            return;
          }

          [self dispatchShortenCompletion:completion url:shortURL error:nil];
        }];

  [task resume];
}

#pragma mark - Helpers

- (void)dispatchCompletion:(void (^)(NSArray<NSString *> * _Nullable domains,
                                      NSError * _Nullable error))completion
                   domains:(NSArray<NSString *> * _Nullable)domains
                     error:(NSError * _Nullable)error {
  if (!completion) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    completion(domains, error);
  });
}

- (void)dispatchShortenCompletion:(void (^)(NSString * _Nullable shortURL,
                                             NSError * _Nullable error))completion
                               url:(NSString * _Nullable)url
                             error:(NSError * _Nullable)error {
  if (!completion) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    completion(url, error);
  });
}

@end
