//
//  YDProtocolParserSS.m
//  maodou-vpn
//
//  Created by Badwin on 2023/9/12.
//

#import "ExtProtocolParserSS.h"

static uint16_t __http_proxy_port__ = 1082;
static NSString *__log_level__ = @"info";
static bool __global_geosite_enable__ = false;
static bool __global_geoip_enable__ = false;
static NSMutableArray *__directDomainList__ = nil;
static NSMutableArray *__proxyDomainList__ = nil;
static NSMutableArray *__blockDomainList__ = nil;

@implementation ExtProtocolParserSS


+(void)setHttpProxyPort:(uint16_t)port {
    __http_proxy_port__ = port;
}

+(uint16_t)HttpProxyPort {
    return __http_proxy_port__;
}

+(void)setLogLevel:(NSString *)level {
    __log_level__ = level;
}

+ (void)setGlobalProxyEnable:(BOOL)enable {
    __global_geosite_enable__ = !enable;
    __global_geoip_enable__ = !enable;
}

+ (void)setDirectDomainList:(NSArray *)list {
    __directDomainList__ = list.mutableCopy;
}

+ (void)setProxyDomainList:(NSArray *)list {
    __proxyDomainList__ = list.mutableCopy;
}

+ (void)setBlockDomainList:(NSArray *)list {
    __blockDomainList__ = list.mutableCopy;
}

+(NSString *)decodeBase64:(NSString *)base64Str {
    NSInteger pp = base64Str.length % 4;
    if (pp == 3) {
        base64Str = [base64Str stringByAppendingString:@"="];
    }
    else if (pp == 2) {
        base64Str = [base64Str stringByAppendingString:@"=="];
    }
    else if (pp == 1) {
        base64Str = [base64Str stringByAppendingString:@"==="];
    }
    NSData *payload = [[NSData alloc] initWithBase64EncodedString:base64Str options:0];
    NSString *prefix = [[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding];
    return prefix;
}


+(nullable NSDictionary *)parseSS:(NSString *)uri {
    uri = [uri stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    
//ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTpkZGZlMTdmMS1iM2UwLTQ3YTYtYjk2NS03ZGM0Nzc2Y2VjNzA@hz-cm.youtushop.link:41533#%E6%96%B0%E5%8A%A0%E5%9D%A104
//ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTpLR005a1dAYzRoMG05eDJ0Ny1mYm5vZGUtYXIwMi42cHpmd2YuY29tOjU2MTAw#Argentina-02
    
    NSString *url = @"";
    if ([uri containsString:@"@"]) {
        NSArray <NSString *>*list = [uri componentsSeparatedByString:@"@"];
        NSString *prefix = [ExtProtocolParserSS decodeBase64:list[0]];
        url = [prefix stringByAppendingString:@"@"];
        url = [url stringByAppendingString:list[1]];
    }
    else{
        NSArray <NSString *>*list = [uri componentsSeparatedByString:@"#"];
        NSString *prefix = [ExtProtocolParserSS decodeBase64:list[0]];
        url = [prefix stringByAppendingString:@"#"];
        url = [url stringByAppendingString:list[1]];
    }
    NSArray <NSString *>*list = [url componentsSeparatedByString:@"#"];
    if (list.count != 2) return nil;
    NSString *remark = list[1];
    NSArray<NSString *> *userInfos =  [list[0] componentsSeparatedByString:@"@"];
    if (userInfos.count != 2) return nil;
    
    NSString *userInfo = userInfos[0];
    NSString *serverInfo = userInfos[1];
    
    NSArray<NSString *> *accountPasswords = [userInfo componentsSeparatedByString:@":"];
    NSArray<NSString *> *ipPorts = [serverInfo componentsSeparatedByString:@":"];
    
    if (accountPasswords.count != 2 || ipPorts.count != 2) return nil;
    
    NSString *address = ipPorts[0];
    NSNumber *port = @([ipPorts[1] integerValue]);
    
    NSString *tag = @"proxy";
    NSString *network = @"tcp";
    NSString *security = @"";
    NSString *method = accountPasswords[0];
    NSString *password = accountPasswords[1];
    BOOL ota = false;
    
    NSString *kcpKey;
    NSString *quicSecurity;
    NSString *quicKey;
    NSString *quicHeaderType;
    
    NSString *wspath;
    NSString *wshost;
    BOOL allowInsecure = false;
    
    if (!address || !port || !password || !tag || !network || !security) return nil;
    NSMutableDictionary *configuration = [NSMutableDictionary new];
    configuration[@"log"] = @{@"loglevel":__log_level__};
    NSMutableArray *rules = @[].mutableCopy;
    
    if (__proxyDomainList__.count > 0) {
        NSDictionary *A = @{
            @"type": @"field",
            @"domain": __proxyDomainList__,
            @"outboundTag": tag
        };
        [rules addObject:A];
    }

    if (__blockDomainList__.count > 0) {
        NSDictionary *A = @{
            @"type": @"field",
            @"domain": __blockDomainList__,
            @"outboundTag": @"block"
        };
        [rules addObject:A];
    }
    
    if (__global_geosite_enable__) {
        NSDictionary *A = @{
            @"type": @"field",
            @"domain": @[@"geosite:category-ads-all"],
            @"outboundTag": @"block"
        };
        NSDictionary *B = @{
            @"type": @"field",
            @"domain": @[@"geosite:cn"],
            @"outboundTag": @"direct"
        };
        [rules addObject:A];
        [rules addObject:B];
    }
    
    if (__global_geoip_enable__) {
        NSDictionary *A = @{
            @"type": @"field",
            @"ip": @[@"geoip:private", @"geoip:cn"],
            @"outboundTag": @"direct"
        };
        [rules addObject:A];
    }
    
    if (__global_geoip_enable__ || __global_geosite_enable__) {
        NSDictionary *C = @{
            @"type": @"field",
            @"domain": @[@"geosite:geolocation-!cn"],
            @"outboundTag": tag
        };
        [rules addObject:C];
    }
    
    if (!__global_geoip_enable__ && !__global_geosite_enable__) {
        NSDictionary *all = @{
            @"type":@"field",
            @"outboundTag":tag,
            @"port":@"0-65535"
        };
        [rules addObject:all];
    }
    
    configuration[@"routing"] = @{
        @"domainStrategy" : @"AsIs",
        @"rules" : rules
    };

    NSMutableArray *inbounds = [NSMutableArray new];
    configuration[@"inbounds"] = inbounds;
    
    NSDictionary *defaultInbound = @{
        @"listen" : @"127.0.0.1",
        @"protocol" : @"http",
        @"settings" : @{
            @"timeout" : @60
        },
        @"tag" : @"httpinbound",
        @"port" : @(__http_proxy_port__)
    };
    [inbounds addObject:defaultInbound];
    NSMutableArray *outbounds = [NSMutableArray new];
    configuration[@"outbounds"] = outbounds;
    NSMutableDictionary *outbound = @{
        @"protocol":@"shadowsocks",
        @"tag":tag,
        @"settings": @{
            @"servers" : @[
                @{
                    @"address":address,
                    @"port":port,
                    @"level":@8,
                    @"method":method,
                    @"ota":@(ota),
                    @"password":password
                }
            ]
        },
    }.mutableCopy;
    NSMutableDictionary *streamSettings = @{
        @"security" : security,
        @"network" : network,
        @"tcpSettings":@{@"header":@{@"type":@"none"}},
    }.mutableCopy;
    outbound[@"streamSettings"] = streamSettings;
    
    if ([security isEqualToString:@"tls"]) {
        streamSettings[@"tlsSettings"] = @{@"allowInsecure":@(allowInsecure), @"serverName":address};
    }
    
    if ([network isEqualToString:@"ws"]) {
        if (wspath && wshost) {
            outbound[@"streamSettings"] = @{
                @"security" : security,
                @"network" : network,
                @"wsSettings" : @{
                    @"headers":@{
                        @"Host":wshost
                    },
                    @"path":wspath
                }
            };
        }
    }
    else if ([network isEqualToString:@"quic"]) {
        if ([network isEqualToString:@"quic"] && quicKey && quicSecurity && quicHeaderType) {
            outbound[@"streamSettings"] = @{
                @"security" : security,
                @"network" : network,
                @"quicSettings" : @{
                    @"header":@{
                        @"type":quicHeaderType
                    },
                    @"key":quicKey,
                    @"security":quicSecurity
                }
            };
        }
    }
    else if ([network isEqualToString:@"tcp"]) {
        if ([security isEqualToString:@"xtls"]) {
            outbound[@"streamSettings"] = @{
                @"security" : security,
                @"network" : network,
                @"xtlsSettings" : @{
                    @"serverName":address
                }
            };
        }
    }
    else if ([network isEqualToString:@"kcp"]) {
        if (kcpKey) {
            outbound[@"streamSettings"] = @{
                @"security" : security,
                @"network" : network,
                @"kcpSettings": @{
                    @"congestion": [NSNumber numberWithBool:false],
                    @"downlinkCapacity": @100,
                    @"header": @{
                        @"type": @"none"
                    },
                    @"mtu": @1350,
                    @"readBufferSize": @1,
                    @"seed": kcpKey,
                    @"tti": @50,
                    @"uplinkCapacity": @12,
                    @"writeBufferSize": @1
                },
            };
        }
    }
    [outbounds addObject:outbound];
    NSDictionary *direct = @{
        @"tag": @"direct",
        @"protocol": @"freedom",
        @"settings": @{}
    };
    
    NSDictionary *block = @{
        @"tag": @"block",
        @"protocol": @"blackhole",
        @"settings": @{
            @"response": @{
                @"type": @"http"
            }
        }
    };
    [outbounds addObject:direct];
    [outbounds addObject:block];
    
    NSMutableDictionary *dns = @{}.mutableCopy;
    dns[@"servers"] = @[];
    configuration[@"dns"] = dns;
    configuration[@"remark"] = remark;
    configuration[@"address"] = address;
    configuration[@"port"] = port;
    return configuration;
}

@end
