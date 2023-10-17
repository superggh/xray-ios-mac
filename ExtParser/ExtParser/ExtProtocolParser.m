//
//  xVPNProtocolParser.m
//  xVPN
//
//  Created by LinkV on 2022/11/1.
//

#import "ExtProtocolParser.h"
#import "ExtProtocolParserVless.h"
#import "ExtProtocolParserVmess.h"
#import "ExtProtocolParserTrojan.h"
#import "ExtProtocolParserSS.h"

static uint16_t __http_proxy_port__ = 1082;
static NSMutableArray *__directDomainList__ = nil;
static NSMutableArray *__proxyDomainList__ = nil;
static NSMutableArray *__blockDomainList__ = nil;

@implementation ExtProtocolParser

+(void)setHttpProxyPort:(uint16_t)port {
    __http_proxy_port__ = port;
    [ExtProtocolParserVless setHttpProxyPort:port];
    [ExtProtocolParserVmess setHttpProxyPort:port];
    [ExtProtocolParserTrojan setHttpProxyPort:port];
    [ExtProtocolParserSS setHttpProxyPort:port];
}

+(uint16_t)HttpProxyPort {
    return __http_proxy_port__;
}

+(void)setLogLevel:(NSString *)level {
    [ExtProtocolParserVless setLogLevel:level];
    [ExtProtocolParserVmess setLogLevel:level];
    [ExtProtocolParserTrojan setLogLevel:level];
    [ExtProtocolParserSS setLogLevel:level];
}

+ (void)setGlobalProxyEnable:(BOOL)enable {
    [ExtProtocolParserVless setGlobalProxyEnable:enable];
    [ExtProtocolParserVmess setGlobalProxyEnable:enable];
    [ExtProtocolParserTrojan setGlobalProxyEnable:enable];
    [ExtProtocolParserSS setGlobalProxyEnable:enable];
}

+ (void)setDirectDomainList:(NSArray *)list {
    __directDomainList__ = list.mutableCopy;
    [ExtProtocolParserVless setDirectDomainList:list];
    [ExtProtocolParserVmess setDirectDomainList:list];
    [ExtProtocolParserTrojan setDirectDomainList:list];
    [ExtProtocolParserSS setDirectDomainList:list];
}

+ (void)setProxyDomainList:(NSArray *)list {
    __proxyDomainList__ = list.mutableCopy;
    [ExtProtocolParserVless setProxyDomainList:list];
    [ExtProtocolParserVmess setProxyDomainList:list];
    [ExtProtocolParserTrojan setProxyDomainList:list];
    [ExtProtocolParserSS setProxyDomainList:list];
}

+ (void)setBlockDomainList:(NSArray *)list {
    __blockDomainList__ = list.mutableCopy;
    [ExtProtocolParserVless setBlockDomainList:list];
    [ExtProtocolParserVmess setBlockDomainList:list];
    [ExtProtocolParserTrojan setBlockDomainList:list];
    [ExtProtocolParserSS setBlockDomainList:list];
}

+(nullable NSDictionary *)parse:(NSString *)uri protocol:(xVPNProtocol)protocol {
    
    switch (protocol) {
        case xVPNProtocolVmess:
            return [ExtProtocolParserVmess parseVmess:uri];
            
        case xVPNProtocolVless:
            return [ExtProtocolParserVless parseVless:uri];
            
        case xVPNProtocolTrojan:
            return [ExtProtocolParserTrojan parseTrojan:uri];
            
        case xVPNProtocolSS:
            return [ExtProtocolParserSS parseSS:uri];
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
    NSDictionary *configuration = [ExtProtocolParser parse:list[1] protocol:protocol];
    return configuration;
}

@end

