//
//  YDVPNViewController.m
//  Yo Wish
//
//  Created by Badwin on 2023/1/13.
//  Copyright © 2023 RongVP. All rights reserved.
//

#import "ViewController.h"
#import <Masonry/Masonry.h>
#import <CoreImage/CIFilterBuiltins.h>
#import <NetworkExtension/NetworkExtension.h>
#import "AppDelegate.h"
#import "YDVTextField.h"
#import "YDXButton.h"
#import "YDVPNListItem.h"
#import <ExtParser/ExtParser.h>

@interface NSData (XBase64)
+ (NSData *)dataWithBase64EncodedStringx:(NSString *)string;
@end

@implementation NSData (XBase64)

+ (NSData *)dataWithBase64EncodedStringx:(NSString *)string
{
    if (![string length]) return nil;
    
    NSData *decoded = nil;
    
#if __MAC_OS_X_VERSION_MIN_REQUIRED < __MAC_10_9 || __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    
    if (![NSData instancesRespondToSelector:@selector(initWithBase64EncodedString:options:)])
    {
        decoded = [[self alloc] initWithBase64Encoding:[string stringByReplacingOccurrencesOfString:@"[^A-Za-z0-9+/=]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, [string length])]];
    }
    else
    
#endif
        
    {
        decoded = [[self alloc] initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters];
    }
    
    return [decoded length]? decoded: nil;
}
@end


NSString *const kYDApplicationVPNListKey = @"kYDApplicationVPNListKey";


@interface ViewController ()<NSTextFieldDelegate, NSTableViewDelegate, NSTableViewDataSource, YDVPNListItemDelegate>
@property (weak) IBOutlet NSView *controlBackgroundView;
@property (weak) IBOutlet YDVPopTextField *vpnTextField;
@property (weak) IBOutlet YDXButton *startConnectButton;
@property (weak) IBOutlet NSTextField *addressLabel;
@property (weak) IBOutlet NSTextField *portLab;
@property (weak) IBOutlet NSTextField *protocolLab;
@property (weak) IBOutlet NSTextField *statusLab;
@property (weak) IBOutlet NSScrollView *scrollView;
@property (weak) IBOutlet NSTableView *tableView;
@property (nonatomic, strong)NSMutableArray *dataSource;
@property (weak) IBOutlet NSTextField *remarkLab;
@property (weak) IBOutlet YDXButton *speedTestButton;
@property (weak) IBOutlet YDXButton *globalModeButton;

@property (weak) IBOutlet NSTextField *httpLabel;
@property (weak) IBOutlet NSTextField *httpContentLab;
@property (weak) IBOutlet NSTextField *socksLab;
@property (weak) IBOutlet NSTextField *socksContentLab;

@property (weak) IBOutlet NSTextField *xremarkLab;
@property (weak) IBOutlet NSTextField *xAddressLab;
@property (weak) IBOutlet NSTextField *xPortLab;
@property (weak) IBOutlet NSTextField *xProtocolLab;
@property (weak) IBOutlet NSTextField *xStatusLab;


@end

@implementation ViewController
{
    NSInteger selectedRow;
    NSString *currentConfiguration;
    dispatch_queue_t mPingQueue;
    dispatch_queue_t mWorkQueue;
    BOOL mConnected;
    id<YDVPNManagerDelegate> _delegate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    self.vpnTextField.delegate = self;
    // vmess, vless, trojan, ss
    self.vpnTextField.stringValue = @"";
    self.startConnectButton.wantsLayer = YES;
    self.startConnectButton.layer.backgroundColor = [NSColor colorWithRed:2/255.0 green:187/255.0 blue:0/255.0 alpha:1.0].CGColor;
    self.startConnectButton.contentTintColor = [NSColor whiteColor];
    self.startConnectButton.layer.cornerRadius = 10;
    self.startConnectButton.layer.masksToBounds = YES;
    
    self.globalModeButton.normalImage = self.globalModeButton.image;
    self.globalModeButton.selectedImage = [NSImage imageNamed:@"globe-central-south-asia"];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    [self.tableView registerNib:[[NSNib alloc]initWithNibNamed:@"YDVPNListItem" bundle:[NSBundle mainBundle]] forIdentifier:@"YDVPNListItem"];
    
    self.scrollView.wantsLayer = YES;
    self.scrollView.layer.cornerRadius = 12;
    self.dataSource = [NSMutableArray new];
    _delegate = (id<YDVPNManagerDelegate>)NSApp.delegate;
    self.dataSource = (NSMutableArray *)[_delegate getObjectOfClass:NSMutableArray.class forKey:kYDApplicationVPNListKey];
    if (!self.dataSource) {
        self.dataSource = [NSMutableArray new];
    }
    else {
        selectedRow = -1;
        [self.dataSource enumerateObjectsUsingBlock:^(NSDictionary  *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            BOOL selected = [obj[@"selected"] boolValue];
            if (selected) {
                selectedRow = idx;
                *stop = YES;
                [self parse:obj[@"uri"]];
            }
        }];
        if (selectedRow == -1 && self.dataSource.count > 0) {
            NSDictionary *obj = self.dataSource[0];
            [self parse:obj[@"uri"]];
            selectedRow = 0;
        }
        [self.tableView reloadData];
    }
    self.scrollView.automaticallyAdjustsContentInsets = NO;
    self.scrollView.contentInsets = NSEdgeInsetsMake(50, 0, 0, 0);
    [self.scrollView.contentView setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scrollViewBoundsDidChange:) name:NSViewBoundsDidChangeNotification object:nil];
    self.controlBackgroundView.wantsLayer = YES;


    [[ExtVPNManager sharedManager] setupVPNManager];
    [self parseRequest];
    self.globalModeButton.selected = [_delegate getBoolForKey:@"kYDApplicationGlobalVPNModeEnable" defaultValue:NO];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vpnConnectionStatusDidChanged) name:@"kApplicationVPNStatusDidChangeNotification" object:nil];
}

-(void)scrollViewBoundsDidChange:(NSNotification *)notification {
    NSClipView *view = self.scrollView.contentView;
    CGFloat offset = -(-50 - view.documentVisibleRect.origin.y);
    self.controlBackgroundView.layer.backgroundColor = [NSColor colorWithWhite:1 alpha:offset/50.0].CGColor;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)controlTextDidEndEditing:(NSNotification *)obj {
    [self parseRequest];
}

- (void)reloadItem:(NSString *)uri rsp:(NSDictionary *)rsp{
    if (!rsp) return;
    NSString *pings = rsp[@"pings"];
    NSData *xpings = [pings dataUsingEncoding:NSUTF8StringEncoding];
    if (xpings.length == 0){
        NSLog(@"Invalid pings response");
        return;
    }
    NSArray *xxpings = [NSJSONSerialization JSONObjectWithData:xpings options:NSJSONReadingMutableContainers error:nil];
    __block NSInteger index = -1;
    [self.dataSource enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *xuri = obj[@"uri"];
        if ([xuri isEqualToString:uri]){
            *stop = YES;
            index = idx;
            NSMutableDictionary *x = obj.mutableCopy;
            x[@"ping"] = xxpings.firstObject;
            self.dataSource[idx] = x;
        }
    }];
    NSIndexSet *set = [NSIndexSet indexSetWithIndex:index];
    NSIndexSet *columnSet = [NSIndexSet indexSetWithIndex:0];
    [self.tableView reloadDataForRowIndexes:set columnIndexes:columnSet];
}

- (IBAction)speedTestButtonClick:(id)sender {
    if (!mPingQueue) {
        mPingQueue = dispatch_queue_create("sg.linkv.ping.queue", DISPATCH_QUEUE_SERIAL);
    }
    for (int i = 0; i < self.dataSource.count; i++) {
        NSDictionary *info = self.dataSource[i];
        NSMutableDictionary *x = info.mutableCopy;
        [x removeObjectForKey:@"ping"];
        self.dataSource[i] = x;
    }
    [self.tableView reloadData];
    
//    NSMutableArray *dataSource = self.dataSource.mutableCopy;
//    NETunnelProviderSession *connection = (NETunnelProviderSession *)_providerManager.connection;
//    __weak ViewController *weakSelf = self;
//    dispatch_async(mPingQueue, ^{
//        for (NSDictionary *info in dataSource) {
//            __strong ViewController*strongSelf = weakSelf;
//            if (!strongSelf) break;
//            NSString *uri = info[@"uri"];
//            NSDictionary *configuration = [ExtProtocolParser parseURI:uri];
//            NSArray <NSDictionary *>* outbounds = configuration[@"outbounds"];
//            __block NSDictionary *proxy = nil;
//            [outbounds enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//                NSString *protocol = obj[@"protocol"];
//                if ([protocol isEqualToString:@"vmess"] || [protocol isEqualToString:@"vless"]) {
//                    *stop = YES;
//                    proxy = obj;
//                }
//            }];
//            if (proxy) {
//                NSArray <NSDictionary *>*vnext = proxy[@"settings"][@"vnext"];
//                NSString *ip = vnext[0][@"address"];
//                NSDictionary *msg = @{@"action":@"ping", @"pings":@[ip]};
//                NSError *returnError;
//                NSData *x = [NSJSONSerialization dataWithJSONObject:msg options:NSJSONWritingPrettyPrinted error:nil];
//                dispatch_semaphore_t sem = dispatch_semaphore_create(0);
//                __block NSDictionary *r = nil;
//                [connection sendProviderMessage:x returnError:&returnError responseHandler:^(NSData * _Nullable responseData) {
//                    if (responseData) {
//                        NSDictionary *rsp = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:nil];
//                        r = rsp;
//                    }
//                    dispatch_semaphore_signal(sem);
//                }];
//                if (!returnError)
//                    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
//
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    [strongSelf reloadItem:uri rsp:r];
//                });
//            }
//        }
//    });
}

- (IBAction)globalModeButtonClick:(id)sender {
    self.globalModeButton.selected = !self.globalModeButton.selected;
    [_delegate setBool:self.globalModeButton.selected forKey:@"kYDApplicationGlobalVPNModeEnable"];
    
    ExtVPNManager.sharedManager.isGlobalMode = self.globalModeButton.selected;
    NSLog(@"isGlobalMode: %@", @(ExtVPNManager.sharedManager.isGlobalMode));   
}

-(BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    NSMutableDictionary *selected = [self.dataSource[selectedRow] mutableCopy];
    selected[@"selected"] = @(NO);
    self.dataSource[selectedRow] = selected;
    
    selected = [self.dataSource[row] mutableCopy];
    BOOL isSelected = [selected[@"selected"] boolValue];
    selected[@"selected"] = @(!isSelected);
    self.dataSource[row] = selected;
    
    NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndex:selectedRow];
    NSIndexSet *columnIndexes = [NSIndexSet indexSetWithIndex:0];
    [self.tableView reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];
    
    rowIndexes = [NSIndexSet indexSetWithIndex:row];
    [self.tableView reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];
    
    [_delegate setObject:self.dataSource forKey:kYDApplicationVPNListKey];
    selectedRow = row;
    
    NSString *uri = selected[@"uri"];
    NSDictionary *configuration = [ExtProtocolParser parseURI:uri];
    [self parseOutbounds:configuration uri:uri];
    return YES;
}

-(void)onDeleteButtonClick:(NSDictionary *)info cellView:(NSTableCellView *)cellView {
    NSInteger row = [self.dataSource indexOfObject:info];
    if (row != NSNotFound) {
        [self.dataSource removeObjectAtIndex:row];
        [_delegate setObject:self.dataSource forKey:kYDApplicationVPNListKey];
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:row];
        [self.tableView removeRowsAtIndexes:indexSet withAnimation:(NSTableViewAnimationSlideRight)];
    }
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView{
  return self.dataSource.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    YDVPNListItem *cellView = [tableView makeViewWithIdentifier:@"YDVPNListItem" owner:nil];
    cellView.delegate = self;
    [cellView reloadData:self.dataSource[row]];
    return cellView;
}

-(CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row{
  return 37;
}

-(CGFloat)tableView:(NSTableView *)tableView sizeToFitWidthOfColumn:(NSInteger)column{
  return 250;
}

- (IBAction)add2ListView:(id)sender {
//    ECHO Test

    [[ExtVPNManager sharedManager] echo];
    
    if (!currentConfiguration) {
        [_delegate makeToast:NSLocalizedString(@"Configuration Invaild", nil)];
        return;
    }
    __block BOOL found = NO;
    [self.dataSource enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *uri = obj[@"uri"];
        if ([uri isEqualToString:currentConfiguration]) {
            found = YES;
            *stop = YES;
        }
    }];
    if (!found) {
        NSDictionary *uri = @{@"uri":currentConfiguration, @"selected":@(YES)};
        [self.dataSource addObject:uri];
        [self.tableView reloadData];
        [_delegate setObject:self.dataSource forKey:kYDApplicationVPNListKey];
    }
    else {
        [_delegate makeToast:NSLocalizedString(@"Configuration Added", nil) inView:self.view maxWidth:120];
    }
}

-(void)parseRequest {
    NSString *uri = self.vpnTextField.stringValue;
    if (uri.length == 0) return;
    if ([uri hasPrefix:@"http"]) {
        [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:uri] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSString *xresponse = nil;
            if (!error) {
                xresponse  = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self handleResponse:xresponse];
            });
        }] resume];
        
    }
    else {
        [self parse:uri];
    }
}

-(void)handleResponse:(nullable NSString *)response {
    if (!response) {
        self.statusLab.stringValue = @"Invalid Configuration";
        return;
    }
    [self parse:response];
}

-(void)parse:(NSString *)uri {
    NSDictionary *configuration = [ExtProtocolParser parseURI:uri];
    if (configuration) {
        __block BOOL found = NO;
        [self.dataSource enumerateObjectsUsingBlock:^(NSDictionary *jobj, NSUInteger jdx, BOOL * _Nonnull jstop) {
            NSString *jstr = jobj[@"uri"];
            if ([jstr isEqualToString:uri]) {
                found = YES;
                *jstop = YES;
            }
        }];
        if (!found) {
            NSDictionary *info = @{@"uri":uri, @"selected":@(YES)};
            [self.dataSource addObject:info];
            selectedRow = self.dataSource.count - 1;
            [_delegate setObject:self.dataSource forKey:kYDApplicationVPNListKey];
            [self.tableView reloadData];
        }
    }
    if (!configuration) {
        NSData *data = [NSData dataWithBase64EncodedStringx:uri];
        NSString *more = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSMutableArray <NSString *>*x = [more componentsSeparatedByString:@"\n"].mutableCopy;
        uri = x.firstObject;
        NSString *lastURI = x.lastObject;
        if (lastURI.length == 0) [x removeLastObject];
        configuration = [ExtProtocolParser parseURI:uri];
        if (configuration) {
            [x enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSDictionary *info = @{@"uri":obj};
                __block NSInteger found = -1;
                NSDictionary *cfg = [ExtProtocolParser parseURI:obj];
                [self.dataSource enumerateObjectsUsingBlock:^(NSDictionary *jobj, NSUInteger jdx, BOOL * _Nonnull jstop) {
                    NSString *jstr = jobj[@"uri"];
                    NSDictionary *jcfg = [ExtProtocolParser parseURI:jstr];
                    if ([jstr isEqualToString:obj] || [self configuration:cfg equalTo:jcfg]) {
                        found = YES;
                        *jstop = YES;
                    }
                }];
                if (found == -1) {
                    [self.dataSource addObject:info];
                }
                else {
                    [self.dataSource replaceObjectAtIndex:found withObject:info];
                }
            }];
        }
        [_delegate setObject:self.dataSource forKey:kYDApplicationVPNListKey];
        [self.tableView reloadData];
    }
    if (!configuration) {
        self.statusLab.stringValue = @"Invalid Configuration";
        return;
    }
    [self parseOutbounds:configuration uri:uri];
}

-(BOOL)configuration:(NSDictionary *)configuration equalTo:(NSDictionary *)x {
    NSString *remark1 = configuration[@"remark"];
    NSString *remark2 = x[@"remark"];
    return [remark1 hasPrefix:@"剩余流量"] && [remark2 hasPrefix:@"剩余流量"];
}

-(void)parseOutbounds:(NSDictionary *)configuration uri:(NSString *)uri{
    currentConfiguration = uri;
    NSArray <NSDictionary *>* outbounds = configuration[@"outbounds"];
    __block NSDictionary *proxy = nil;
    [outbounds enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *protocol = obj[@"protocol"];
        if ([protocol isEqualToString:@"vmess"] || [protocol isEqualToString:@"vless"]) {
            *stop = YES;
            proxy = obj;
        }
    }];
    
    if (proxy) {
        self.statusLab.stringValue = @"Configuration Vaild";
        NSArray <NSDictionary *>*vnext = proxy[@"settings"][@"vnext"];
        self.addressLabel.stringValue = vnext[0][@"address"];
        self.portLab.stringValue = [NSString stringWithFormat:@"%@", vnext[0][@"port"]];
        self.protocolLab.stringValue = proxy[@"protocol"];
        self.remarkLab.stringValue = configuration[@"remark"];
    }
}

-(void)mouseDown:(NSEvent *)event {
    [self.view.window makeFirstResponder:nil];
}
- (IBAction)startConnect:(id)sender {
    if (ExtVPNManager.sharedManager.status == YDVPNStatusConnected) {
        [[ExtVPNManager sharedManager] disconnect];
    }
    else {
        NSString *url = self.dataSource[selectedRow][@"uri"];
        [[ExtVPNManager sharedManager] connect:url];
    }
}

-(void)setVPNStatusConnected:(BOOL)connected {
    
    CGFloat alphaValue = connected ? 0.0 : 1.0;
    CGFloat alphaValue2 = connected ? 1.0 : 0.0;
    
    self.httpLabel.alphaValue = alphaValue;
    self.httpContentLab.alphaValue = alphaValue;
    self.socksLab.alphaValue = alphaValue;
    self.socksContentLab.alphaValue = alphaValue;
    
    self.httpLabel.hidden = NO;
    self.httpContentLab.hidden = NO;
    self.socksLab.hidden = NO;
    self.socksContentLab.hidden = NO;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.2;
        self.xremarkLab.animator.alphaValue = alphaValue;
        self.xAddressLab.animator.alphaValue = alphaValue;
        self.xProtocolLab.animator.alphaValue = alphaValue;
        self.xPortLab.animator.alphaValue = alphaValue;
        self.xStatusLab.animator.alphaValue = alphaValue;
        
        self.statusLab.animator.alphaValue = alphaValue;
        self.addressLabel.animator.alphaValue = alphaValue;
        self.portLab.animator.alphaValue = alphaValue;
        self.protocolLab.animator.alphaValue = alphaValue;
        self.remarkLab.animator.alphaValue = alphaValue;
        
        self.httpLabel.animator.alphaValue = alphaValue2;
        self.httpContentLab.animator.alphaValue = alphaValue2;
        self.socksLab.animator.alphaValue = alphaValue2;
        self.socksContentLab.animator.alphaValue = alphaValue2;
    }];
    if (connected) {
        self.statusLab.textColor = [NSColor systemGreenColor];
        self.statusLab.stringValue = @"Connected";
        self.startConnectButton.title = NSLocalizedString(@"Disconnect", nil);
        self.startConnectButton.layer.backgroundColor = [NSColor systemRedColor].CGColor;
    }
    else {
        self.statusLab.textColor = [NSColor systemRedColor];
        self.statusLab.stringValue = @"Disconnected";
        self.startConnectButton.title = NSLocalizedString(@"Connect", nil);
        self.startConnectButton.layer.backgroundColor = [NSColor colorWithRed:2/255.0 green:187/255.0 blue:0/255.0 alpha:1.0].CGColor;
    }
}

-(void)vpnConnectionStatusDidChanged{
    switch (ExtVPNManager.sharedManager.status) {
        case YDVPNStatusConnected:{
            self.statusLab.textColor = [NSColor systemGreenColor];
            self.statusLab.stringValue = @"Connected";
            
            self.startConnectButton.title = NSLocalizedString(@"Disconnect", nil);
            self.startConnectButton.layer.backgroundColor = [NSColor systemRedColor].CGColor;
            
            
            if (self.vpnTextField.stringValue.length == 0) {
                self.vpnTextField.stringValue = ExtVPNManager.sharedManager.connectedURL;
                [self parseRequest];
            }
        }
            break;
            
        case YDVPNStatusConnecting: {
            self.statusLab.textColor = [NSColor systemOrangeColor];
            self.statusLab.stringValue = @"Connecting";
        }
            break;
            
        case YDVPNStatusDisconnected:{
            self.statusLab.textColor = [NSColor systemRedColor];
            self.statusLab.stringValue = @"Disconnected";
            
            self.startConnectButton.title = NSLocalizedString(@"Connect", nil);
            self.startConnectButton.layer.backgroundColor = [NSColor colorWithRed:2/255.0 green:187/255.0 blue:0/255.0 alpha:1.0].CGColor;
        }
            break;
        default:
            break;
    }

}

@end
