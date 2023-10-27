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
    
 
    [[ETVPNManager sharedManager] setupVPNManager];
    
    self.protocolTextField.delegate = self;
    
    //    TODO: This is protocol address, vmess, vless, trojan, ss
    self.protocolTextField.text = @"";
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vpnConnectionStatusDidChanged) name:@"kApplicationVPNStatusDidChangeNotification" object:nil];
    ETVPNManager.sharedManager.isGlobalMode = YES;
    
    NSDictionary *info = [ETProtocolParser parseURI:self.protocolTextField.text];
    NSLog(@"%@", info);
    
}

-(void)vpnConnectionStatusDidChanged{
    switch (ETVPNManager.sharedManager.status) {
        case YDVPNStatusConnected:{
            self.statusLab.textColor = [UIColor systemGreenColor];
            self.statusLab.text = @"Connected";
            
            [self.startConnectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
            [self.startConnectButton setTitleColor:UIColor.redColor forState:UIControlStateNormal];
            
            if (self.protocolTextField.text.length == 0) {
                self.protocolTextField.text = ETVPNManager.sharedManager.connectedURL;
            }
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
    if (ETVPNManager.sharedManager.status == YDVPNStatusConnected) {
        [[ETVPNManager sharedManager] disconnect];
    }
    else{
        [ETVPNManager.sharedManager connect:self.protocolTextField.text];
    }
}

- (IBAction)echoButton:(id)sender {
    [[ETVPNManager sharedManager] echo];
}

@end
