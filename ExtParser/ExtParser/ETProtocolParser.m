//
//  xVPNProtocolParser.m
//  xVPN
//
//  Created by LinkV on 2022/11/1.
//

#import "ETProtocolParser.h"
#import "ETProtocolParserVless.h"
#import "ETProtocolParserVmess.h"
#import "ETProtocolParserTrojan.h"
#import "ETProtocolParserSS.h"

static uint16_t __http_proxy_port__ = 1082;
static NSMutableArray *__directDomainList__ = nil;
static NSMutableArray *__proxyDomainList__ = nil;
static NSMutableArray *__blockDomainList__ = nil;

@implementation ETProtocolParser

+(void)setHttpProxyPort:(uint16_t)port {
    __http_proxy_port__ = port;
    [ETProtocolParserVless setHttpProxyPort:port];
    [ETProtocolParserVmess setHttpProxyPort:port];
    [ETProtocolParserTrojan setHttpProxyPort:port];
    [ETProtocolParserSS setHttpProxyPort:port];
}

+(uint16_t)HttpProxyPort {
    return __http_proxy_port__;
}

+(void)setLogLevel:(NSString *)level {
    [ETProtocolParserVless setLogLevel:level];
    [ETProtocolParserVmess setLogLevel:level];
    [ETProtocolParserTrojan setLogLevel:level];
    [ETProtocolParserSS setLogLevel:level];
}

+ (void)setGlobalProxyEnable:(BOOL)enable {
    [ETProtocolParserVless setGlobalProxyEnable:enable];
    [ETProtocolParserVmess setGlobalProxyEnable:enable];
    [ETProtocolParserTrojan setGlobalProxyEnable:enable];
    [ETProtocolParserSS setGlobalProxyEnable:enable];
}

+ (void)setDirectDomainList:(NSArray *)list {
    __directDomainList__ = list.mutableCopy;
    [ETProtocolParserVless setDirectDomainList:list];
    [ETProtocolParserVmess setDirectDomainList:list];
    [ETProtocolParserTrojan setDirectDomainList:list];
    [ETProtocolParserSS setDirectDomainList:list];
}

+ (void)setProxyDomainList:(NSArray *)list {
    __proxyDomainList__ = list.mutableCopy;
    [ETProtocolParserVless setProxyDomainList:list];
    [ETProtocolParserVmess setProxyDomainList:list];
    [ETProtocolParserTrojan setProxyDomainList:list];
    [ETProtocolParserSS setProxyDomainList:list];
}

+ (void)setBlockDomainList:(NSArray *)list {
    __blockDomainList__ = list.mutableCopy;
    [ETProtocolParserVless setBlockDomainList:list];
    [ETProtocolParserVmess setBlockDomainList:list];
    [ETProtocolParserTrojan setBlockDomainList:list];
    [ETProtocolParserSS setBlockDomainList:list];
}

+(nullable NSDictionary *)parse:(NSString *)uri protocol:(xVPNProtocol)protocol {
    
    switch (protocol) {
        case xVPNProtocolVmess:
            return [ETProtocolParserVmess parseVmess:uri];
            
        case xVPNProtocolVless:
            return [ETProtocolParserVless parseVless:uri];
            
        case xVPNProtocolTrojan:
            return [ETProtocolParserTrojan parseTrojan:uri];
            
        case xVPNProtocolSS:
            return [ETProtocolParserSS parseSS:uri];
        default:
            break;
    }
    return nil;
}

+ (NSDictionary *)parseURI:(NSString *)uri {
    NSArray <NSString *>*list = [uri componentsSeparatedByString:@"//"];
    xVPNProtocol protocol;
    if (list.count != 2) {
        list = [uri componentsSeparatedByString:@":"];
        if (list.count != 2) {
            return nil;
        }
    }
    if ([list[0] hasPrefix:@"vmess"]) {
        protocol = xVPNProtocolVmess;
    }
    else if ([list[0] hasPrefix:@"vless"]) {
        protocol = xVPNProtocolVless;
    }
    else if ([list[0] hasPrefix:@"trojan"]) {
        protocol = xVPNProtocolTrojan;
    }
    else if ([list[0] hasPrefix:@"ss"]) {
        protocol = xVPNProtocolSS;
    }
    else {
        return nil;
    }
    NSDictionary *configuration = [ETProtocolParser parse:list[1] protocol:protocol];
    return configuration;
}

@end

