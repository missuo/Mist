//
//  MSTShortLinkService.h
//  Mist
//
//  Created by Vincent Yang on 12/14/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSTShortLinkService : NSObject

- (void)fetchAvailableDomainsWithAPIKey:(NSString *)apiKey
                               completion:(void (^)(NSArray<NSString *> * _Nullable domains,
                                                    NSError * _Nullable error))completion;

- (void)createShortURLForURL:(NSString *)targetURL
                       domain:(NSString *)domain
                        apiKey:(NSString *)apiKey
                    completion:(void (^)(NSString * _Nullable shortURL,
                                         NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
