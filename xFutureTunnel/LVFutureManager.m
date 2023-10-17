//
//  NSSocks5Manager.m
//  AppProxyProvider
//
//  Created by LinkV on 2022/10/22.
//

#import "LVFutureManager.h"
#include <arpa/inet.h>
#include <dns.h>
#include <resolv.h>
#import <Future/Future.h>
#import <ExtParser/ExtParser.h>
#import <arpa/inet.h>
#import <mach/mach.h>
#import <resolv.h>
#import <sys/sysctl.h>
#import <sys/time.h>
#import <sys/utsname.h>



@interface LVFutureManager ()<FutureAppleNetworkinterface>

@end

@implementation LVFutureManager {
    
    NEPacketTunnelProvider *_mProvider;
    
    NSMutableArray *_allDnsServer;
    
    NSURLSession *_mSession;
    dispatch_queue_t _mTimerQueue;
    
    long long _mUdpTimeout;
    long long _mTcpTimeout;
    
    long long _mHttpDownFlow;
    long long _mHttpUpFlow;
    long long _mTcpDownFlow;
    long long _mTcpUpFlow;
    
    BOOL _mRunning;
}
+(instancetype)sharedManager {
    static LVFutureManager *__manager__ = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __manager__ = [[self alloc] init];
        [__manager__ setup];
    });
    return __manager__;
}

+ (void)setLogLevel:(xLogLevel)level{
    switch (level) {
        case xLogLevelVerbose:
            [ExtProtocolParser setLogLevel:@"verbose"];
            break;
            
        case xLogLevelWarning:
            [ExtProtocolParser setLogLevel:@"warning"];
            break;
            
        case xLogLevelInfo:
            [ExtProtocolParser setLogLevel:@"info"];
            break;
            
        case xLogLevelError:
            [ExtProtocolParser setLogLevel:@"error"];
            break;
    }
}

+ (void)setGlobalProxyEnable:(BOOL)enable {
    [ExtProtocolParser setGlobalProxyEnable:enable];
    NSString *file = [[NSBundle mainBundle] pathForResource:@"geosite" ofType:@"dat"];
    if (file && [[NSFileManager defaultManager] fileExistsAtPath:file]) {
        NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/"];
        FutureInitV2Env(path);
    }
}

- (void)setup {
    _allDnsServer = [NSMutableArray new];
    _mTimerQueue = dispatch_queue_create("sg.linkv.work.queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(_mTimerQueue, ^{
        while (true) {
            [self getStats];
            struct timespec timeout;
            timeout.tv_sec = 1;
            timeout.tv_nsec = 0;
            nanosleep(&timeout, NULL);
        }
    });
}

+(NSString *)version {
    return [NSString stringWithFormat:@"%@-%@",@"25", FutureCheckVersionX()];
}

- (void)setPacketTunnelProvider:(NEPacketTunnelProvider *)provider {
    _mProvider = provider;
}

- (NEPacketTunnelNetworkSettings *)createNetworkSetting {
    
    [_allDnsServer removeAllObjects];
    
    NEPacketTunnelNetworkSettings *networkSettings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"254.1.1.1"];
    NSMutableSet *dns = [NSMutableSet setWithArray:[LVFutureManager sharedManager].DNS];
    
    [_allDnsServer addObjectsFromArray:dns.allObjects];
    networkSettings.DNSSettings = [[NEDNSSettings alloc] initWithServers:_allDnsServer];
    networkSettings.MTU = @(4096);
    
    // 此处其实是创建一个虚拟 IP 地址，需要自行创建路由
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"198.18.0.1"] subnetMasks:@[@"255.255.255.0"]];
    ipv4Settings.includedRoutes = @[[NEIPv4Route defaultRoute]];
    ipv4Settings.excludedRoutes = @[];
    networkSettings.IPv4Settings = ipv4Settings;
    
    NEProxySettings *proxySettings = [NEProxySettings new];
    NEProxyServer *http = [[NEProxyServer alloc] initWithAddress:@"127.0.0.1" port:[ExtProtocolParser HttpProxyPort]];
    proxySettings.HTTPEnabled = YES;
    proxySettings.HTTPSEnabled = YES;
    proxySettings.HTTPServer = http;
    proxySettings.HTTPSServer = http;
    proxySettings.excludeSimpleHostnames = YES;
    proxySettings.autoProxyConfigurationEnabled = NO;
    proxySettings.exceptionList = @[
        @"captive.apple.com",
        @"10.0.0.0/8",
        @"localhost",
        @"*.local",
        @"172.16.0.0/12",
        @"198.18.0.0/15",
        @"114.114.114.114.dns",
        @"192.168.0.0/16"
    ];
    networkSettings.proxySettings = proxySettings;
    return networkSettings;
}

- (long)writePacket:(NSData* _Nullable)payload {
    if (!payload || payload.length == 0) return 0;
    [_mProvider.packetFlow writePackets:@[payload] withProtocols:@[@(AF_INET)]];
    return payload.length;
}

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    NSDictionary *xray = nil;
    NSString *payload;
    if (options[@"uri"]) {
        payload = options[@"uri"];
        xray = [ExtProtocolParser parseURI:payload];
        BOOL global = [options[@"global"] boolValue];
        [LVFutureManager setGlobalProxyEnable:global];
    }
    if (!xray) {
        NSError *error = [NSError errorWithDomain:@"Invalid Configuration" code:-1 userInfo:nil];
        return completionHandler(error);
    }
    NSData *c = [NSJSONSerialization dataWithJSONObject:xray options:NSJSONWritingPrettyPrinted error:nil];
    NSString *r = FutureStartVPN(c, payload);
    if (r.length > 0){
        NSLog(@"Start vpn instance:%@", r);
        NSError *error = [NSError errorWithDomain:@"Invalid json" code:204 userInfo:nil];
        completionHandler(error);
        return;
    }
    NSLog(@"vpn configuration: %@", xray);
    FutureRegisterAppleNetworkInterface(self);
    _mRunning = YES;
    __weak LVFutureManager *weakSelf = self;
    NEPacketTunnelNetworkSettings *networkSettings = [self createNetworkSetting];
    [_mProvider setTunnelNetworkSettings:networkSettings completionHandler:^(NSError * _Nullable e) {
        THROW_EXCEPTION(e);
        __strong LVFutureManager *strongSelf = weakSelf;
        [strongSelf readPackets];
        completionHandler(e);
    }];
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    FutureStopVPN();
    completionHandler();
}

-(BOOL)changeURL:(NSString *)url {
    _mRunning = NO;
    NSDictionary *xray = [ExtProtocolParser parseURI:url];
    if (!xray) {
        NSLog(@"Invalid protocol url:%@", url);
        return NO;
    }
    NSData *c = [NSJSONSerialization dataWithJSONObject:xray options:NSJSONWritingPrettyPrinted error:nil];
    NSString *r = FutureChangeURL(c, url);
    NSLog(@"Restart vpn instance:%@", r);
    FutureRegisterAppleNetworkInterface(self);
    _mRunning = YES;
    return r.length == 0;
}

+ (int64_t)duration {
    return FutureDuration();
}

- (NSArray<NSString *> *)DNS {
    NSMutableArray *dnsList = [NSMutableArray array];
    res_state x = malloc(sizeof(struct __res_state));
    if (res_ninit(x) == 0) {
        for (int i = 0; i < x->nscount; i++) {
            NSString *s = [NSString stringWithUTF8String:inet_ntoa(x->nsaddr_list[i].sin_addr)];
            [dnsList addObject:s];
        }
    }
    res_nclose(x);
    res_ndestroy(x);
    free(x);
    
    NSMutableArray *defaultx = @[@"1.0.0.1", @"8.8.4.4", @"8.8.8.8", @"1.1.1.1"].mutableCopy;
    NSInteger ii = arc4random()%4;
    [dnsList addObject:defaultx[ii]];
    [defaultx removeObjectAtIndex:ii];
    
    NSInteger jj = arc4random()%3;
    [dnsList addObject:defaultx[jj]];
    return dnsList;
}


- (void)readPackets {
    __weak LVFutureManager *weakSelf = self;
    [_mProvider.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        __strong LVFutureManager *strongSelf = weakSelf;
        if (strongSelf->_mRunning) {
            for (int i = 0; i < (int)packets.count; i ++) {
                FutureWriteAppleNetworkInterfacePacket(packets[i]);
            }
        }
        [strongSelf readPackets];
    }];
}

- (void)wake {
    
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    completionHandler();
}

- (void)google204Delay:(nullable VPNDelayResponse)response {
    dispatch_async(dispatch_get_global_queue(0, 0 ), ^{
        int64_t duration = FutureGoogle204Delay();
        response(duration != -1, duration);
    });
}

- (void)getStats {
//    int64_t downlink = FutureQueryStats(@"proxy", @"downlink");
//    int64_t uplink = FutureQueryStats(@"proxy", @"uplink");
//    if ([self.delegate respondsToSelector:@selector(onConnectionSpeedReport:uplink:)]) {
//        [self.delegate onConnectionSpeedReport:downlink uplink:NO];
//        [self.delegate onConnectionSpeedReport:uplink uplink:YES];
//    }
}
@end
