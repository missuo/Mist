#import <Foundation/Foundation.h>
#import "MSTS3HostConfig.h"
#import "MSTS3Provider.h"

static NSURLRequest *lastUploadRequest;

@interface MSTUploadTestProtocol : NSURLProtocol
@end

@implementation MSTUploadTestProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
  return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
  return request;
}

- (void)startLoading {
  lastUploadRequest = self.request;
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc]
      initWithURL:self.request.URL
       statusCode:200
      HTTPVersion:@"HTTP/1.1"
     headerFields:nil];
  [self.client URLProtocol:self didReceiveResponse:response
       cacheStoragePolicy:NSURLCacheStorageNotAllowed];
  [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {
}
@end

int main(void) {
  @autoreleasepool {
    NSURLSessionConfiguration *sessionConfig =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    sessionConfig.protocolClasses = @[[MSTUploadTestProtocol class]];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    MSTS3Provider *provider = [[MSTS3Provider alloc] init];
    MSTS3HostConfig *config = [[MSTS3HostConfig alloc] init];
    config.bucket = @"test-bucket";
    config.accessKey = @"test-access-key";
    config.secretKey = @"test-secret-key";
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    NSArray<NSArray<NSString *> *> *files = @[
      @[@"image-1_2.png", @"image-1_2.png"],
      @[@"Screenshot 2026-09-10 at 11.07.22.png",
        @"Screenshot%202026-09-10%20at%2011.07.22.png"],
      @[@"image #1?x=2&y+3.png", @"image%20%231%3Fx%3D2%26y%2B3.png"],
      @[@"100%.png", @"100%25.png"],
      @[@"literal%20name.png", @"literal%2520name.png"],
      @[@"café 你好😀.png", @"caf%C3%A9%20%E4%BD%A0%E5%A5%BD%F0%9F%98%80.png"],
      @[@"image [1](2).png", @"image%20%5B1%5D%282%29.png"]
    ];
    NSArray<NSArray<NSString *> *> *paths = @[
      @[@"https://cdn.example.com", @"{filename}.{ext}", @"https://cdn.example.com/", @""],
      @[@"https://cdn.example.com/base%20path/", @"uploads 2026/{filename}.{ext}",
        @"https://cdn.example.com/base%20path/uploads%202026/", @"uploads%202026/"],
      @[@"", @"cdn.example.com/uploads 2026/{filename}.{ext}",
        @"https://cdn.example.com/uploads%202026/", @"cdn.example.com/uploads%202026/"],
      @[@"", @"cdn.example.com:8443/{filename}.{ext}",
        @"https://cdn.example.com:8443/", @"cdn.example.com%3A8443/"],
      @[@"", @"[::1]:8443/{filename}.{ext}",
        @"https://[::1]:8443/", @"%5B%3A%3A1%5D%3A8443/"]
    ];
    NSUInteger count = files.count * paths.count * 2;
    NSUInteger failures = 0;
    for (NSUInteger index = 0; index < count; index++) {
      @autoreleasepool {
        NSArray<NSString *> *file = files[index % files.count];
        NSArray<NSString *> *path = paths[(index / files.count) % paths.count];
        config.urlPrefix = path[0];
        config.saveKeyPath = path[1];
        BOOL customEndpoint = (index / (files.count * paths.count)) % 2 != 0;
        config.providerType = customEndpoint ? MSTS3ProviderTypeBackblazeB2
                                             : MSTS3ProviderTypeAmazonS3;
        config.endpoint = @"https://s3.us-west-002.backblazeb2.com";
        __block NSString *result = nil;
        __block NSError *uploadError = nil;
        dispatch_semaphore_t completed = dispatch_semaphore_create(0);
        [provider uploadData:data filename:file[0] withConfig:config
                     session:session progress:nil
                  completion:^(NSString *url, NSError *error) {
                    result = url;
                    uploadError = error;
                    dispatch_semaphore_signal(completed);
                  }];
        if (dispatch_semaphore_wait(completed,
                dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0) {
          fprintf(stderr, "FAIL: Upload did not finish.\n");
          return 1;
        }
        NSString *expected = [path[2] stringByAppendingString:file[1]];
        NSString *expectedPath = [NSString stringWithFormat:@"%@%@%@",
            customEndpoint ? @"/test-bucket/" : @"/", path[3], file[1]];
        NSURLComponents *requestURL = [NSURLComponents
            componentsWithURL:lastUploadRequest.URL resolvingAgainstBaseURL:NO];
        if (![requestURL.percentEncodedPath isEqualToString:expectedPath] ||
            ![lastUploadRequest.HTTPMethod isEqualToString:@"PUT"] ||
            requestURL.query != nil || requestURL.fragment != nil) {
          fprintf(stderr, "FAIL: Upload URL changed: %s\n",
                  lastUploadRequest.URL.absoluteString.UTF8String);
          failures++;
        }
        if (uploadError || ![result isEqualToString:expected]) {
          fprintf(stderr, "FAIL: %s\nExpected: %s\nActual: %s\nError: %s\n",
                  file[0].UTF8String, expected.UTF8String, result.UTF8String,
                  uploadError.description.UTF8String);
          failures++;
        }
      }
    }
    [session finishTasksAndInvalidate];
    printf("%lu tests, %lu failures\n", (unsigned long)count,
           (unsigned long)failures);
    return failures ? 1 : 0;
  }
}
