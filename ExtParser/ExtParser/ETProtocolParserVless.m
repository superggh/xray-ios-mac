//
//  YDProtocolParserVless.m
//  maodou-vpn
//
//  Created by Badwin on 2023/9/12.
//

#import "ETProtocolParserVless.h"
#import "ETProtocolParser.h"

static uint16_t __http_proxy_port__ = 1082;
static NSString *__log_level__ = @"info";
static bool __global_geosite_enable__ = false;
static bool __global_geoip_enable__ = false;
static NSMutableArray *__directDomainList__ = nil;
static NSMutableArray *__proxyDomainList__ = nil;
static NSMutableArray *__blockDomainList__ = nil;

@implementation ETProtocolParserVless


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


+(nullable NSDictionary *)parseVless:(NSString *)uri {
    NSString *source = uri;
    uri = [uri stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray <NSString *> *info = [uri componentsSeparatedByString:@"@"];
    if (info.count < 2) {
        NSData *payload = [[NSData alloc] initWithBase64EncodedString:uri options:0];
        if (payload.length > 0) {
            uri = [[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding];
            info = [uri componentsSeparatedByString:@"@"];
            if (info.count < 2) {
                NSLog(@"Invalid payload: %@", source);
                return nil;
            }
        }
    }
    
    NSString *uuid = info[0];
    NSArray <NSString *>*config = [info[1] componentsSeparatedByString:@"?"];
    if (config.count < 2) {
        return nil;
    }
    
    NSArray <NSString *>*ipAddress = [config[0] componentsSeparatedByString:@":"];
    if (ipAddress.count < 2) {
        return nil;
    }
    NSString *address = ipAddress[0];
    NSNumber *port = @([ipAddress[1] integerValue]);

    NSArray <NSString *> *suffix = [config[1] componentsSeparatedByString:@"#"];
    if (suffix.count < 2) {
        return nil;
    }
    NSString *remark = suffix[1];
    NSString *tag = @"proxy";
    NSArray <NSString *> *parameters = [suffix[0] componentsSeparatedByString:@"&"];
    
    NSString *network;
    NSString *security = @"none";
    NSString *flow = @"";
    
    NSString *kcpKey;
    
    NSString *quicSecurity;
    NSString *quicKey;
    NSString *quicHeaderType;
    
    NSString *wspath;
    NSString *wshost;
    
    NSString *fingerprint = @"";
    
    NSString *sni = nil;
    NSString *alpn = nil;
    NSString *serviceName = nil;
    
    NSString *email = nil;
    
//vless://c8cd43b0-8674-4595-a2fd-66183ce506f9@161.202.3.131:35073/?type=quic&security=none&quicSecurity=aes-128-gcm&key=quic-1234&headerType=none#%E6%96%B0%E5%8A%A0%E5%9D%A1-vless-quic
    
//vless://18fbec6c-7ad5-49ff-aedd-da4d8af85eb6@161.202.3.131:32966/?type=kcp&security=none&headerType=none&seed=RUXdF0Zfha#%E6%96%B0%E5%8A%A0%E5%9D%A1-vless-kcp
    
    for (NSString *p in parameters) {
        NSArray <NSString *> *items = [p componentsSeparatedByString:@"="];
        if (items.count < 2) continue;
        
        if ([items[0] isEqualToString:@"type"]) {
            network = items[1];
        }
        else if ([items[0] isEqualToString:@"security"]) {
            security = items[1];
        }
        else if ([items[0] isEqualToString:@"flow"]) {
            flow = items[1];
        }
        else if ([items[0] isEqualToString:@"key"]) {
            quicKey = items[1];
        }
        else if ([items[0] isEqualToString:@"quicSecurity"]) {
            quicSecurity = items[1];
        }
        else if ([items[0] isEqualToString:@"headerType"]) {
            quicHeaderType = items[1];
        }
        else if ([items[0] isEqualToString:@"seed"]) {
            kcpKey = items[1];
        }
        else if ([items[0] isEqualToString:@"fp"]) {
            fingerprint = items[1];
        }
        else if ([items[0] isEqualToString:@"sni"]) {
            sni = items[1];
        }
        else if ([items[0] isEqualToString:@"alpn"]) {
            alpn = items[1];
        }
        else if ([items[0] isEqualToString:@"serviceName"]) {
            serviceName = items[1];
        }
        else if ([items[0] isEqualToString:@"email"]) {
            email = items[1];
        }
    }
    if (!address || !port || !uuid || !tag || !network || !security) return nil;
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
    
    NSMutableDictionary *user =  @{
        @"encryption":@"none",
        @"id":uuid,
        @"flow":flow,
        @"level":@0
    }.mutableCopy;
    if (email) {
        user[@"email"] = email;
    }
    NSMutableDictionary *outbound = @{
        @"protocol":@"vless",
        @"tag":tag,
        @"settings": @{
            @"vnext" : @[
                @{
                    @"address":address,
                    @"port":port,
                    @"users" :@[ user ]
                }
            ]
        },
        @"streamSettings":@{
            @"security" : security,
            @"network" : network
        }
    }.mutableCopy;
    
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
        if ([network isEqualToString:@"quic"]) {
            if (quicKey && quicSecurity && quicHeaderType) {
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
    else if ([network isEqualToString:@"grpc"]) {
        if (serviceName && alpn && sni) {
            outbound[@"streamSettings"] = @{
                @"network": @"grpc",
                @"security": @"tls",
                @"tlsSettings": @{
                    @"allowInsecure": [NSNumber numberWithBool:false],
                    @"serverName": sni,
                    @"alpn": @[
                        alpn,
                        @"http/1.1"
                    ],
                    @"fingerprint": fingerprint,
                    @"show": @(false)
                },
                @"grpcSettings": @{
                    @"serviceName": serviceName,
                    @"multiMode": [NSNumber numberWithBool:false],
                    @"idle_timeout": @60,
                    @"health_check_timeout": @20,
                    @"permit_without_stream": [NSNumber numberWithBool:false],
                    @"initial_windows_size": @0
                }
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
