//
//  NSSocks5Manager.h
//  AppProxyProvider
//
//  Created by LinkV on 2022/10/22.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

#define THROW_EXCEPTION(v) if(v) {NSLog(@"xx-%@", v); return;}

NS_ASSUME_NONNULL_BEGIN

typedef void(^VPNDelayResponse)(BOOL isSuccess, float delay);

typedef enum : NSUInteger {
    xLogLevelVerbose,
    xLogLevelInfo,
    xLogLevelWarning,
    xLogLevelError
} xLogLevel;

@interface LVFutureManager : NSObject
+ (instancetype)sharedManager;

/// SDK  版本号
+ (NSString *)version;

/// 日志级别
/// - Parameter level: 日志级别
+ (void)setLogLevel:(xLogLevel)level;


/// 设置 PacketProvider
/// - Parameter provider: 提供者
- (void)setPacketTunnelProvider:(NEPacketTunnelProvider *)provider;

/// 打开隧道
/// - Parameters:
///   - options: 参数
///   - completionHandler: 打开完成回调
- (void)startTunnelWithOptions:(nullable NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler;

/// 停止隧道
/// - Parameters:
///   - reason: 停止原因
///   - completionHandler: 停止完成回调
- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler;

/// 唤醒扩展进程
- (void)wake;

/// 使用节点进行 Google 204 网络延迟测试
/// - Parameter response: 测试结果返回
- (void)google204Delay:(nullable VPNDelayResponse)response;

/// 操作系统睡眠事件
/// - Parameter completionHandler: 睡眠时间完成回调
- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler;

/// 切换节点
/// - Parameter url: 节点 URL
- (BOOL)changeURL:(NSString *)url;

/// 返回 SDK 可用时长
+ (int64_t)duration;

@end

NS_ASSUME_NONNULL_END
