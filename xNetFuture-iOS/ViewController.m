//
//  ViewController.m
//  xNetFuture-iOS
//
//  Created by Badwin on 2023/8/17.
//

#import "ViewController.h"
#import <ExtParser/ExtParser.h>
#import <NetworkExtension/NetworkExtension.h>

@interface ViewController ()<UITextFieldDelegate>
{
    NETunnelProviderManager *_providerManager;
}
@property (weak, nonatomic) IBOutlet UITextField *protocolTextField;
@property (weak, nonatomic) IBOutlet UILabel *statusLab;

@property (weak, nonatomic) IBOutlet UIButton *startConnectButton;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
 
    [[ExtVPNManager sharedManager] setupVPNManager];
    
    self.protocolTextField.delegate = self;
    
//    TODO: This is protocol address
    self.protocolTextField.text = @"";
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vpnConnectionStatusDidChanged) name:@"kApplicationVPNStatusDidChangeNotification" object:nil];
}

-(void)vpnConnectionStatusDidChanged{
    switch (ExtVPNManager.sharedManager.status) {
        case YDVPNStatusConnected:{
            self.statusLab.textColor = [UIColor systemGreenColor];
            self.statusLab.text = @"Connected";
            
            [self.startConnectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
            [self.startConnectButton setTitleColor:UIColor.redColor forState:UIControlStateNormal];
        }
            break;
            
        case YDVPNStatusConnecting: {
            self.statusLab.textColor = [UIColor systemOrangeColor];
            self.statusLab.text = @"Connecting";
        }
            break;
            
        case YDVPNStatusDisconnected:{
            self.statusLab.textColor = [UIColor systemRedColor];
            self.statusLab.text = @"Disconnected";
            [self.startConnectButton setTitle:@"Connect" forState:UIControlStateNormal];
            [self.startConnectButton setTitleColor:UIColor.systemGreenColor forState:UIControlStateNormal];
        }
            break;
            
        default:
            break;
    }
}

-(void)textFieldDidEndEditing:(UITextField *)textField {
    
}

- (IBAction)startConnectButtonClick:(id)sender {
    if (!_providerManager) {
        return;
    }
    NETunnelProviderSession *session = (NETunnelProviderSession *)_providerManager.connection;
    NSString *title = [self.startConnectButton titleForState:UIControlStateNormal];
    if ([title isEqualToString:NSLocalizedString(@"Connect", nil)]) {
        NSString *uri = self.protocolTextField.text;
        NSError *error;
        
        BOOL isGlobalMode = YES;
        
        NSDictionary *providerConfiguration = @{@"type":@(0), @"uri":uri, @"global":@(isGlobalMode)};
        NETunnelProviderProtocol *protocolConfiguration = (NETunnelProviderProtocol *)_providerManager.protocolConfiguration;
        NSMutableDictionary *copy = protocolConfiguration.providerConfiguration.mutableCopy;
        copy[@"configuration"] = providerConfiguration;
        protocolConfiguration.providerConfiguration = copy;
        [_providerManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"saveToPreferencesWithCompletionHandler:%@", error);
            }
        }];
        [session startVPNTunnelWithOptions:@{@"uri":uri, @"global":@(isGlobalMode)} andReturnError:&error];
        if (error) {
            NSLog(@"%@", error);
        }
    }
    else {
        [session stopVPNTunnel];
    }
}

- (IBAction)echoButton:(id)sender {
        NETunnelProviderSession *connection = (NETunnelProviderSession *)_providerManager.connection;
        NSDictionary *echo = @{@"type":@1};
        [connection sendProviderMessage:[NSJSONSerialization dataWithJSONObject:echo options:(NSJSONWritingPrettyPrinted) error:nil] returnError:nil responseHandler:^(NSData * _Nullable responseData) {
    
            NSString *x = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            NSLog(@"%@", x);
    
        }];
}

@end
