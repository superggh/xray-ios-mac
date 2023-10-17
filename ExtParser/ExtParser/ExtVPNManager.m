//
//  YDVPNManager.m
//  VPNExtension
//
//  Created by Badwin on 2023/1/15.
//  Copyright © 2023 RongVP. All rights reserved.
//

#import "ExtVPNManager.h"
#import <ExtParser/ExtParser.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif
#import <CommonCrypto/CommonCrypto.h>
#import "SimplePing.h"

NSString *const kApplicationVPNServerAddress = @"com.ext.vpn.x";
NSString *const kApplicationVPNLocalizedDescription = @"Ext VPN Packet Tunnel";

static NSString *__auth__ = @"";
static NSString *__groundID__ = @"group.com.ext.vpn";

typedef void(^YDFetchCompletion)(NETunnelProviderManager *manager);


@interface ExtVPNManager ()<SimplePingDelegate>

@end

@interface ExtVPNManager ()
@property (nonatomic, strong)NSUserDefaults *userDefaults;
@property (nonatomic)BOOL isExtension;
@property (nonatomic)NSInteger notifier;
@property (nonatomic, strong)NSMutableDictionary *info;
@end


@implementation ExtVPNManager
{
    NETunnelProviderManager *_providerManager;
    NSTimer *_durationTimer;
    NSTimer *_pingTimer;
    YDPingResponse _rsp;
}
+(instancetype)sharedManager{
    static ExtVPNManager *__manager__;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __manager__ = [[self alloc] init];
        [__manager__ configure];
    });
    return __manager__;
}

+ (NSString *)md5:(NSString *)content{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    NSData *fileData = [content dataUsingEncoding:NSUTF8StringEncoding];
    CC_MD5_Update(&md5, [fileData bytes], (CC_LONG)[fileData length]);
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);
    NSString *result = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                        digest[0], digest[1],
                        digest[2], digest[3],
                        digest[4], digest[5],
                        digest[6], digest[7],
                        digest[8], digest[9],
                        digest[10], digest[11],
                        digest[12], digest[13],
                        digest[14], digest[15]];
#pragma clang diagnostic pop
    return result;
}

+(void)setGroupID:(NSString *)groupId {
    __groundID__ = groupId;
}

-(void)configure {
    _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:__groundID__];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionStatusDidChangeNotification:) name:NEVPNStatusDidChangeNotification object:nil];
    [_userDefaults addObserver:self forKeyPath:@"notifier" options:(NSKeyValueObservingOptionNew) context:nil];
}

-(void)setupVPNManager:(YDFetchCompletion)completion {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        if (managers.count == 0) {
            [self createVPNConfiguration:completion];
            if (error) {
                NSLog(@"loadAllFromPreferencesWithCompletionHandler: %@", error);
            }
            return;
        }
        [self handlePreferences:managers completion:completion];
    }];
    
}

-(void)setupVPNManager {
    [self setupVPNManager:^(NETunnelProviderManager *manager) {
        [self setupConnection:manager];
    }];
}

-(void)setupConnection:(NETunnelProviderManager *)manager {
    _providerManager = manager;
    NEVPNConnection *connection = manager.connection;
    if (connection.status == NEVPNStatusConnected) {
        _status = YDVPNStatusConnected;
        NETunnelProviderProtocol *protocolConfiguration = (NETunnelProviderProtocol *)_providerManager.protocolConfiguration;
        NSDictionary *copy = protocolConfiguration.providerConfiguration;
        NSDictionary *configuration = copy[@"configuration"];
        _connectedURL = configuration[@"uri"];
        _connectedDate = [_userDefaults objectForKey:@"connectedDate"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kApplicationVPNStatusDidChangeNotification" object:nil];
    }
}

-(void)setupExtenstionApplication {
    _isExtension = YES;
    _info = [NSMutableDictionary new];
    _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:__groundID__];
    [_userDefaults setObject:NSDate.date forKey:@"connectedDate"];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSDictionary <NSString *, NSNumber *>*vinfo = [_userDefaults objectForKey:@"vinfo"];
    if (_rsp) {
        [vinfo enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
            _rsp(key, obj.intValue);
        }];
    }
    NSLog(@"observeValueForKeyPath keyPath:%@ info:%@", keyPath, vinfo);
}

-(void)reenableManager:(YDFetchCompletion)complection {
    if (_providerManager) {
        if(_providerManager.enabled == NO) {
            NSLog(@"providerManager is disabled, so reenable");
            _providerManager.enabled = YES;
            [_providerManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"saveToPreferencesWithCompletionHandler:%@", error);
                }
            }];
        }
        complection(_providerManager);
    }
    else {
        [self setupVPNManager:^(NETunnelProviderManager *manager) {
            [self setupConnection:manager];
            complection(manager);
        }];
    }
}

-(void)connect:(NSString *)url {
    _connectedURL = url;
    [self reenableManager:^(NETunnelProviderManager *manager) {
        if (!manager){
            return;
        }
        NETunnelProviderSession *session = (NETunnelProviderSession *)_providerManager.connection;
        NSString *uri = url;
        NSError *error;
        NSDictionary *providerConfiguration = @{@"type":@(0), @"uri":uri, @"global":@(self.isGlobalMode)};
        NETunnelProviderProtocol *protocolConfiguration = (NETunnelProviderProtocol *)_providerManager.protocolConfiguration;
        NSMutableDictionary *copy = protocolConfiguration.providerConfiguration.mutableCopy;
        copy[@"configuration"] = providerConfiguration;
        NSLog(@"connect using: %@", providerConfiguration);
        protocolConfiguration.providerConfiguration = copy;
        [_providerManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"saveToPreferencesWithCompletionHandler:%@", error);
            }
        }];
        [session startVPNTunnelWithOptions:@{@"uri":uri, @"global":@(self.isGlobalMode)} andReturnError:&error];
        if (error) {
            NSLog(@"startVPNTunnelWithOptions:%@", error);
        }
    }];

}

-(void)setIsGlobalMode:(BOOL)isGlobalMode {
    if (_isGlobalMode == isGlobalMode) return;
    _isGlobalMode = isGlobalMode;
    if (self.status == YDVPNStatusConnected) {
        [self changeURL:self.connectedURL force:YES];
    }
}
-(void)changeURL:(NSString *)uri {
    [self changeURL:uri force:NO];
}
-(void)changeURL:(NSString *)uri force:(BOOL)force{
    if ([uri isEqualToString:_connectedURL] && force == NO) {
        return;
    }
    [self reenableManager:^(NETunnelProviderManager *manager) {
        if (!manager){
            return;
        }
        _connectedURL = uri;
        NETunnelProviderSession *connection = (NETunnelProviderSession *)_providerManager.connection;
        NSDictionary *providerConfiguration = @{@"type":@(0), @"uri":uri, @"global":@(self.isGlobalMode)};
        NETunnelProviderProtocol *protocolConfiguration = (NETunnelProviderProtocol *)_providerManager.protocolConfiguration;
        NSMutableDictionary *copy = protocolConfiguration.providerConfiguration.mutableCopy;
        copy[@"configuration"] = providerConfiguration;
        NSLog(@"changeURL using: %@", providerConfiguration);
        protocolConfiguration.providerConfiguration = copy;
        [_providerManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"saveToPreferencesWithCompletionHandler:%@", error);
            }
        }];
        NSDictionary *echo = @{@"type":@2, @"uri":uri, @"global":@(self.isGlobalMode)};
        [connection sendProviderMessage:[NSJSONSerialization dataWithJSONObject:echo options:(NSJSONWritingPrettyPrinted) error:nil] returnError:nil responseHandler:^(NSData * _Nullable responseData) {
            NSString *x = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            NSLog(@"%@", x);
        }];
    }];
}

-(void)disconnect {
    NETunnelProviderSession *session = (NETunnelProviderSession *)_providerManager.connection;
    [session stopVPNTunnel];
    NSLog(@"disconnect");
}

-(void)connectionStatusDidChangeNotification:(NSNotification *)notification {
    NEVPNConnection *connection = _providerManager.connection;
    switch (connection.status) {
        case NEVPNStatusInvalid:
            _status = YDVPNStatusDisconnected;
            break;
            
        case NEVPNStatusConnected:{
            _status = YDVPNStatusConnected;
            _connectedDate = NSDate.date;
        }
            break;
            
        case NEVPNStatusConnecting: {
            _status = YDVPNStatusConnecting;
        }
            break;
            
        case NEVPNStatusDisconnected:{
            _status = YDVPNStatusDisconnected;
        }
            break;
            
        case NEVPNStatusReasserting:{
            _status = YDVPNStatusDisconnected;
        }
            break;
        case NEVPNStatusDisconnecting: {
            _status = YDVPNStatusDisconnected;
        }
            break;
            
        default:
            break;
    }
    NSLog(@"extension status did change:%d", (int)connection.status);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kApplicationVPNStatusDidChangeNotification" object:nil];
}

- (void)handlePreferences:(NSArray<NETunnelProviderManager *> * _Nullable)managers completion:(YDProviderManagerCompletion)completion{
    NETunnelProviderManager *manager;
    for (NETunnelProviderManager *item in managers) {
        if ([item.localizedDescription isEqualToString:kApplicationVPNLocalizedDescription]) {
            manager = item;
            break;
        }
    }
    if (manager.enabled == NO) {
        manager.enabled = YES;
        [manager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            completion(manager);
        }];
    }
    else {
        completion(manager);
    }
    NSLog(@"Found a vpn configuration");
}

- (void)createVPNConfiguration:(YDProviderManagerCompletion)completion {
        
    NETunnelProviderManager *manager = [NETunnelProviderManager new];
    NETunnelProviderProtocol *protocolConfiguration = [NETunnelProviderProtocol new];
    
    protocolConfiguration.serverAddress = kApplicationVPNServerAddress;
    
    // providerConfiguration 可以自定义进行存储
    protocolConfiguration.providerConfiguration = @{};
    manager.protocolConfiguration = protocolConfiguration;

    manager.localizedDescription = kApplicationVPNLocalizedDescription;
    manager.enabled = YES;
    [manager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"saveToPreferencesWithCompletionHandler:%@", error);
            completion(nil);
            return;
        }
        [manager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            
            if (error) {
                NSLog(@"loadFromPreferencesWithCompletionHandler:%@", error);
                completion(nil);
            }
            else {
                completion(manager);
            }
        }];
    }];
}

-(void)pingInHost:(NSArray<NSString *> *)ips response:(YDPingResponse)response {
    NSMutableArray *pings = NSMutableArray.new;
    [ips enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *protocol = [ExtProtocolParser parseURI:obj];
        NSString *address = protocol[@"address"];
        SimplePing *ping = [[SimplePing alloc] initWithHostName:address];
        ping.delegate = self;
        ping.tag = obj;
        ping.response = response;
        [pings addObject:ping];
    }];
    NSLog(@"schedule host: %ld", pings.count);
    [self schedule:pings];
}

-(void)schedule:(NSMutableArray <SimplePing *>*)pings{
    [pings enumerateObjectsUsingBlock:^(SimplePing * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj start];
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        [pings enumerateObjectsUsingBlock:^(SimplePing * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj stop];
            if (self.isExtension) {
                if (obj.rtt == 0) {
                    [self.info setObject:@(-1) forKey:obj.tag];
                    [self.userDefaults setObject:self.info forKey:@"vinfo"];
                    [self.userDefaults setObject:@(++self.notifier) forKey:@"notifier"];
                }
                NSLog(@"ping timeout: %@", obj.hostName);
                return;
            }
            if (obj.rtt == 0) {
                obj.response(obj.tag, -1);
                NSLog(@"ping timeout: %@", obj.hostName);
            }
        }];
    });
}

#pragma mark SimplePingDelegate - begin
- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
    long long now = (NSDate.date.timeIntervalSince1970 * 1000);
    NSData *echo = [NSData dataWithBytes:&now length:8];
    pinger.begin = now;
    [pinger sendPingWithData:echo];
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber {
    long long now = (NSDate.date.timeIntervalSince1970 * 1000);
    pinger.rtt = now - pinger.begin;
    if (self.isExtension) {
        [self.info setObject:@(pinger.rtt) forKey:pinger.tag];
        [self.userDefaults setObject:self.info forKey:@"vinfo"];
        [self.userDefaults setObject:@(++self.notifier) forKey:@"notifier"];
    }
    else {
        pinger.response(pinger.tag, pinger.rtt);
    }
}

-(void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
    NSLog(@"didFailWithError: %@", error);
}

#pragma mark SimplePingDelegate - end

-(void)pingInTunnel:(NSArray <NSString *> *)ips response:(YDPingResponse)response {
    _rsp = response;
    if (!_providerManager) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self pingInTunnel:ips response:response];
        });
    }
    else {
        NETunnelProviderSession *connection = (NETunnelProviderSession *)_providerManager.connection;
        [_providerManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"saveToPreferencesWithCompletionHandler:%@", error);
            }
        }];
        NSLog(@"schedule pinger: %ld", ips.count);
        NSDictionary *echo = @{@"type":@3, @"urls":ips};
        [connection sendProviderMessage:[NSJSONSerialization dataWithJSONObject:echo options:(NSJSONWritingPrettyPrinted) error:nil] returnError:nil responseHandler:^(NSData * _Nullable responseData) {
            NSString *x = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            NSLog(@"schedule pinger: %@", x);
        }];
    }
}

-(void)ping:(NSArray *)ips {
    NSMutableArray *pings = NSMutableArray.new;
    [ips enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *protocol = [ExtProtocolParser parseURI:obj];
        NSString *address = protocol[@"address"];
        SimplePing *ping = [[SimplePing alloc] initWithHostName:address];
        ping.delegate = self;
        ping.tag = obj;
        [pings addObject:ping];
    }];
    [self schedule:pings];
}


-(void)ping:(NSArray <NSString *> *)ips response:(YDPingResponse)response {
    if (self.status == YDVPNStatusConnected) {
        [self pingInTunnel:ips response:response];
    }
    else {
        [self pingInHost:ips response:response];
    }
}

-(void)addProtocol:(NSString *)protocol {
    [self addProtocol:protocol name:@"com.jfdream.vpn.default"];
}

-(void)addProtocol:(NSString *)protocol name:(NSString *)name {
    NSMutableArray *locals = [self.storage getObjectOfClass:NSMutableArray.class forKey:name];
    if (!locals) {
        locals = [NSMutableArray new];
    }
    if ([locals containsObject:protocol]) {
        return;
    }
    [locals addObject:protocol];
    [self.storage setObject:locals forKey:name];
    
    
    NSMutableArray *subscriptions = [self.storage getObjectOfClass:NSMutableArray.class forKey:@"com.jfdream.vpn.subscriptions"];
    if (!subscriptions) {
        subscriptions = [NSMutableArray new];
    }
    if (![subscriptions containsObject:name]) {
        [subscriptions addObject:name];
        [self.storage setObject:subscriptions forKey:@"com.jfdream.vpn.subscriptions"];
    }
}

-(void)deleteProtocol:(NSString *)protoccol name:(NSString *)name {
    NSMutableArray *protocols = [self.storage getObjectOfClass:NSMutableArray.class forKey:name];
    if (!protocols) {
        protocols = [NSMutableArray new];
    }
    [protocols removeObject:protoccol];
    if (protocols.count == 0) {
        [self.storage removeValueForKey:name];
        NSMutableArray *subscriptions = [self.storage getObjectOfClass:NSMutableArray.class forKey:@"com.jfdream.vpn.subscriptions"];
        if (!subscriptions) {
            subscriptions = [NSMutableArray new];
        }
        [subscriptions removeObject:name];
        [self.storage setObject:subscriptions forKey:@"com.jfdream.vpn.subscriptions"];
    }
    else {
        [self.storage setObject:protocols forKey:name];
    }
}

-(void)deleteName:(NSString *)name {
    [self.storage removeValueForKey:name];
    NSMutableArray *subscriptions = [self.storage getObjectOfClass:NSMutableArray.class forKey:@"com.jfdream.vpn.subscriptions"];
    if (!subscriptions) {
        subscriptions = [NSMutableArray new];
    }
    [subscriptions removeObject:name];
    [self.storage setObject:subscriptions forKey:@"com.jfdream.vpn.subscriptions"];
}


-(NSArray<NSString *> *)allProtocols {
    NSMutableArray <NSString *>*subscriptions = [self.storage getObjectOfClass:NSMutableArray.class forKey:@"com.jfdream.vpn.subscriptions"];
    NSMutableArray *pro = NSMutableArray.new;
    [subscriptions enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray *protocols = [self.storage getObjectOfClass:NSArray.class forKey:obj];
        if (protocols) {
            [pro addObjectsFromArray:protocols];
        }
    }];
    return pro;
}

-(NSArray<NSString *> *)allProtocols:(NSString *)name {
    NSArray *protocols = [self.storage getObjectOfClass:NSArray.class forKey:name];
    return protocols;
}

-(NSArray <NSString *> *)allSubscriptions {
    NSMutableArray <NSString *>*subscriptions = [self.storage getObjectOfClass:NSMutableArray.class forKey:@"com.jfdream.vpn.subscriptions"];
    return subscriptions;
}


-(void)echo {
    NETunnelProviderSession *connection = (NETunnelProviderSession *)_providerManager.connection;
    if (!connection) return;
    NSDictionary *echo = @{@"type":@1};
    [connection sendProviderMessage:[NSJSONSerialization dataWithJSONObject:echo options:(NSJSONWritingPrettyPrinted) error:nil] returnError:nil responseHandler:^(NSData * _Nullable responseData) {

        NSString *x = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        NSLog(@"%@", x);

    }];
}


@end
