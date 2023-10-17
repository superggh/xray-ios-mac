# An xray/v2ray iOS and macOS client


`Use Apple NetworkExtension`

1. Supports the four common protocols: vmess, vless, ss, and trojan.
2. Automatically parses URLs for the four protocols.
3. Supports Developer ID notarization for Apple Network Extension, enabling global proxy implementation. This technology is quite impressive! By using Network Extension, it essentially proxies all network traffic on the computer, including the system terminal. There's no need to separately configure terminal proxies, which is commonly referred to as 'tun mode'. Moreover, it offers superior stability compared to tun.
4. We also provide SDKs for Windows and Android, utilizing `tun mode` instead of system-wide proxies. The SDK will be released after stable testing.

```objc

// Example
// 1. setup system vpn extension
[[ETVPNManager sharedManager] setupVPNManager];

// 2. connect extension
[ETVPNManager.sharedManager connect:@"vmess://------"];

// 3. change mode
ETVPNManager.sharedManager.isGlobalMode = YES;

// 4. stop connect
[[ETVPNManager sharedManager] disconnect];

```

Download and use it directly

The sdk can be customized, because the compilation needs to use golang, gomobile, if you need the sdk, you can contact me


jfdream1992@gmail.com
