//
//  OCExample.m
//  NWAsyncSocket_Example
//
//  Created by Aaron on 2024/9/13.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

#import "OCExample.h"
@import NWAsyncSocket;

@interface OCExample ()<NWAsyncSocketDelegate>

@end

@implementation OCExample {
    NWAsyncSocket *_socket;
}

- (void)run {
    _socket = [[NWAsyncSocket alloc] initWithHost:@"www.baidu.com" port:443 type:NWAsyncSocketTypeTCPWithTLS delegate:self delegateQueue:nil];
//    [_socket connectWithTimeout:15 completion:^(BOOL isSuccess, NSError * _Nullable error) {
//        NSLog(@"OC: %@ connect completion: %d, %@", _socket, isSuccess, error);
//    }];
    
    BOOL isSuccess = [_socket syncConnectWithTimeout:15] == nil;
    
    NSLog(@"OC: %@ connect: %d", _socket, isSuccess);
}

- (void)didCloseWithSocket:(NWAsyncSocket * _Nonnull)socket { 
    NSLog(@"OC: %@ didClose", socket);
}

- (void)didConnectWithSocket:(NWAsyncSocket * _Nonnull)socket { 
    NSLog(@"OC: %@ didConnect", socket);
}

- (void)didFailWithSocket:(NWAsyncSocket * _Nonnull)socket error:(NSError * _Nonnull)error { 
    NSLog(@"OC: %@ didFail: %@", socket, error);
}

- (void)didReceiveDataWithSocket:(NWAsyncSocket * _Nonnull)socket data:(NSData * _Nonnull)data { 
    NSLog(@"OC: %@ didReceiveData: %@", socket, data);
}

@end
