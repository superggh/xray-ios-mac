//
//  YDProtocolParserVless.h
//  maodou-vpn
//
//  Created by Badwin on 2023/9/12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ExtProtocolParserVless : NSObject
+(nullable NSDictionary *)parseVless:(NSString *)uri;

+(void)setHttpProxyPort:(uint16_t)port;

+(uint16_t)HttpProxyPort;

+(void)setLogLevel:(NSString *)level;

+ (void)setGlobalProxyEnable:(BOOL)enable;

+ (void)setDirectDomainList:(NSArray *)list;

+ (void)setProxyDomainList:(NSArray *)list;

+ (void)setBlockDomainList:(NSArray *)list;
@end

NS_ASSUME_NONNULL_END
