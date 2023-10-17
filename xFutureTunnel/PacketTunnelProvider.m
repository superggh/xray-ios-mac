//
//  PacketTunnelProvider.m
//  VPNPacketTunnel
//
//  Created by badwin on 2023/1/4.
//

#import "PacketTunnelProvider.h"
#import "LVFutureManager.h"
#import <ExtParser/ExtParser.h>

@interface PacketTunnelProvider ()

@end

@implementation PacketTunnelProvider

-(void)setupUserDefaults {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *groundID = @"";
        [ETVPNManager setGroupID:groundID];
        [[ETVPNManager sharedManager] setupExtenstionApplication];
    });
}

+ (void)LOGRedirect {
    NSString *logFilePath = [NSString stringWithFormat:@"%@/Documents/%@", NSHomeDirectory(), @"xray.log"];
    [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:logFilePath] error:nil];
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "w+", stdout);
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "w+", stderr);
}

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    [PacketTunnelProvider LOGRedirect];
    [self setupUserDefaults];
    [LVFutureManager setLogLevel:(xLogLevelError)];
    if (!options) {
        NETunnelProviderProtocol *protocolConfiguration = (NETunnelProviderProtocol *)self.protocolConfiguration;
        NSMutableDictionary *copy = protocolConfiguration.providerConfiguration.mutableCopy;
        options = copy[@"configuration"];
    }
    
    BOOL isGlobalMode = [options[@"global"] boolValue];
    [ETProtocolParser setGlobalProxyEnable:isGlobalMode];
    
    // Add code here to start the process of connecting the tunnel.
    [[LVFutureManager sharedManager] setPacketTunnelProvider:self];
    [[LVFutureManager sharedManager] startTunnelWithOptions:options completionHandler:completionHandler];
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    // Add code here to start the process of stopping the tunnel.
    completionHandler();
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    [self setupUserDefaults];
    // Add code here to handle the message.
    NSDictionary *app = [NSJSONSerialization JSONObjectWithData:messageData options:NSJSONReadingMutableContainers error:nil];
    NSInteger type = [app[@"type"] integerValue];
    NSString *version = [LVFutureManager version];
    // 设置配置文件
    BOOL done = NO;
    if (type == 2) {
        // changeURL
        NSString *uri = app[@"uri"];
        
        BOOL isGlobalMode = [app[@"global"] boolValue];
        [ETProtocolParser setGlobalProxyEnable:isGlobalMode];
        done = [[LVFutureManager sharedManager] changeURL:uri];
    }
    else if (type == 3) {
        // ping
        NSArray *urls = app[@"urls"];
        [[ETVPNManager sharedManager] ping:urls];
    }
    NSDictionary *response = @{@"desc":@(200), @"version":version, @"tunnel_version":@"1.0.7", @"done":@(done), @"duration":@(LVFutureManager.duration)};
    NSData *ack = [NSJSONSerialization dataWithJSONObject:response options:NSJSONWritingPrettyPrinted error:nil];
    completionHandler(ack);
}

#pragma mark SimplePingDelegate - end

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    // Add code here to get ready to sleep.
    completionHandler();
}

- (void)wake {
    // Add code here to wake up.
}

@end
