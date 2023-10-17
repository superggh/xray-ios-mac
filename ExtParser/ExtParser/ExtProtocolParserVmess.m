//
//  YDProtocolParserVmess.m
//  maodou-vpn
//
//  Created by Badwin on 2023/9/12.
//

#import "ExtProtocolParserVmess.h"
#import "ExtProtocolParser.h"

static uint16_t __http_proxy_port__ = 1082;
static NSString *__log_level__ = @"info";
static bool __global_geosite_enable__ = false;
static bool __global_geoip_enable__ = false;
static NSMutableArray *__directDomainList__ = nil;
static NSMutableArray *__proxyDomainList__ = nil;
static NSMutableArray *__blockDomainList__ = nil;

@implementation ExtProtocolParserVmess

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

+(nullable NSDictionary *)parseVmess:(NSString *)uri {
    uri = [uri stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSData *payload = [[NSData alloc] initWithBase64EncodedString:uri options:0];
    if (payload.length == 0) {
        NSLog(@"Invalid vmess:%@", uri);
        return nil;
    }
    NSError *error;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:payload options:NSJSONReadingMutableContainers error:&error];
    if (error) {
        NSLog(@"%@", error);
        return nil;
    }
    NSString *address = info[@"add"];
    NSNumber *port = info[@"port"];
    if (port && ![port isKindOfClass:NSNumber.class]) {
        port = @(port.integerValue);
    }
    NSNumber *aid = info[@"aid"] ? info[@"aid"] : @0;
    if (![aid isKindOfClass:NSNumber.class]) {
        aid = @(aid.integerValue);
    }
    NSString *uuid = info[@"id"];
    NSString *tag = info[@"ps"];
    NSString *tls = info[@"tls"] ? info[@"tls"] : @"none";
    
    NSString *wspath = info[@"path"];
    NSString *wshost = info[@"host"];
    NSString *remark = info[@"remark"] ? info[@"remark"] : info[@"ps"];
    tag = @"proxy";
    NSString *network = info[@"net"];

    NSString *kcpKey = info[@"path"];

    NSString *quicSecurity = info[@"host"];
    NSString *quicKey = info[@"path"];
    NSString *quicHeaderType = info[@"type"];
    
    if (!address || !port || !uuid || !tag || !network) return nil;
    NSMutableDictionary *configuration = [NSMutableDictionary new];
    configuration[@"log"] = @{@"loglevel":__log_level__};
    
    NSMutableArray *rules = @[
    ].mutableCopy;
    
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
        @"mux": @{
            @"concurrency": @8,
            @"enabled": [NSNumber numberWithBool:false]
        },
        @"protocol":@"vmess",
        @"tag":tag,
        @"settings": @{
            @"vnext" : @[
                @{
                    @"address":address,
                    @"port":port,
                    @"users" :@[
                        @{
                            @"encryption":@"",
                            @"security":@"auto",
                            @"alterId":aid,
                            @"id":uuid,
                            @"flow":@"",
                            @"level":@8
                        }
                    ]
                }
            ]
        },
        @"streamSettings" : @{
            @"security" : tls,
            @"network" : network,
            @"tcpSettings": @{
                @"header": @{
                    @"type": @"none"
                }
            },
            @"tlsSettings" : @{@"allowInsecure":@(NO), @"serverName":address}
        }
    }.mutableCopy;
    
    if ([network isEqualToString:@"ws"]) {
        if (wspath && wshost) {
            outbound[@"streamSettings"] = @{
                @"security" : tls,
                @"network" : network,
                @"wsSettings" : @{
                    @"headers":@{
                        @"Host":wshost
                    },
                    @"path":wspath
                },
                @"tlsSettings": @{
                    @"allowInsecure": @(NO),
                    @"serverName": wshost
                },
            };
        }
    }
    else if ([network isEqualToString:@"quic"]) {
        if (quicKey && quicSecurity && quicHeaderType) {
            outbound[@"streamSettings"] = @{
                @"security" : tls,
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
    } else if([network isEqualToString:@"kcp"]) {
        if (kcpKey) {
            outbound[@"streamSettings"] = @{
                @"security" : tls,
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
    configuration[@"remark"] = remark ? remark : @"";
    configuration[@"dns"] = @{
        @"hosts": @{
          @"domain:googleapis.cn": @"googleapis.com"
        },
        @"servers": @[
          @"1.1.1.1"
        ]
    };
    configuration[@"address"] = address;
    configuration[@"port"] = port;
    configuration[@"aid"] = aid;
    configuration[@"uuid"] = uuid;
    return configuration;
}

@end
