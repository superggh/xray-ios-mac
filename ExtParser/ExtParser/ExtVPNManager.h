//
//  YDVPNManager.h
//  VPNExtension
//
//  Created by Badwin on 2023/1/15.
//  Copyright © 2023 RongVP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>
#import <ExtParser/ExtParser.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^YDProviderManagerCompletion)(NETunnelProviderManager *_Nullable manager);
typedef void(^YDPingResponse)(NSString *url, long long rtt);

@class YDItemInfo;

typedef enum : NSUInteger {
    YDVPNStatusIDLE = 0,
    YDVPNStatusConnecting,
    YDVPNStatusConnected,
    YDVPNStatusDisconnected
} YDVPNStatus;


@protocol YDStorage <NSObject>

- (BOOL)setObject:(nullable NSObject<NSCoding> *)object forKey:(NSString *)key;

- (BOOL)setString:(NSString *)value forKey:(NSString *)key;

- (nullable id)getObjectOfClass:(Class)cls forKey:(NSString *)key;

- (nullable NSString *)getStringForKey:(NSString *)key;

- (void)removeValueForKey:(NSString *)key;

@end



@interface ExtVPNManager : NSObject

/// 设置组 ID，用于扩展进程和主进程进行通讯，扩展进程和主进程都需要调用，请 App 启动就调用
/// - Parameter groupId: 组 ID
+(void)setGroupID:(NSString *)groupId;

+(instancetype)sharedManager;

// 主进程调用，扩展进程不要调
-(void)setupVPNManager;

/// 存储
@property (nonatomic, strong)id<YDStorage> storage;

/// 当前连接状态
@property (nonatomic, readonly)YDVPNStatus status;

/// 当前连接节点
@property (nonatomic, strong, readonly)NSString *connectedURL;

/// 连接 VPN 的时间
@property (nonatomic, strong, readonly)NSDate *connectedDate;

/// 是否全局模式，启动 VPN 或者切换节点前设置有效
@property (nonatomic)BOOL isGlobalMode;

/// 开始连接
/// - Parameter url: 节点 URL
-(void)connect:(NSString *)url;

/// 断开连接
-(void)disconnect;

/// 切换节点
/// - Parameter url: 节点 URL
-(void)changeURL:(NSString *)url;

/// 主进程调用，扩展进程不要调
/// - Parameters:
///   - ips: ping 列表
///   - response: ping 响应
-(void)ping:(NSArray <NSString *> *)ips response:(YDPingResponse)response;

/// 添加节点
/// - Parameter protocol: 节点 URL
-(void)addProtocol:(NSString *)protocol;

/// 添加订阅节点
/// - Parameters:
///   - protocol: 节点 URL
///   - name: 订阅名称
-(void)addProtocol:(NSString *)protocol name:(NSString *)name;

/// 删除某个名称下的节点
/// - Parameters:
///   - protoccol: 节点
///   - name: 节点名称
-(void)deleteProtocol:(NSString *)protoccol name:(NSString *)name;

/// 删除某个协议下所有节点
/// - Parameter name: 节点名称
-(void)deleteName:(NSString *)name;

/// 获取所有节点
-(NSArray <NSString *> *)allProtocols;

/// 获取某一个订阅下面所有节点
/// - Parameter name: 订阅名称
-(NSArray <NSString *> *)allProtocols:(NSString *)name;

/// 获取所有订阅列表名称
-(NSArray <NSString *> *)allSubscriptions;

/// 向扩展进程发送活跃检查，DEBU 时使用
-(void)echo;

@end

// 下面节点是在扩展进程中调用的接口
@interface ExtVPNManager (Extension)

/// 扩展进程调用，主进程不要调
/// - Parameter ips: url 列表
-(void)ping:(NSArray *)ips;

/// 扩展进程调用，主进程不要调
-(void)setupExtenstionApplication;
@end


NS_ASSUME_NONNULL_END
