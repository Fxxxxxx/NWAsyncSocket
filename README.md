# NWAsyncSocket

Asynchronous socket based on NWConnection.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

* support protocol defines

```
@objc public enum NWAsyncSocketType: Int {
    case TCP
    case UDP
    case TCPWithTLS
    case UDPWithDTLS
    @available(iOS 15.0, *) case QUIC
}
```

* swift:

```
import NWAsyncSocket

class ViewController: UIViewController {
    
    var socket: NWAsyncSocket?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        socket = .init(host: "www.baidu.com", port: 443, type: .TCPWithTLS, delegate: self)
        socket?.connect(timeout: 15)
        print("\(String(describing: socket)) connect")
        
        socket?.send(data: "hello world!".data(using: .utf8)!, completion: { err in
            print("\(String(describing: self.socket)) send: \(String(describing: err))")
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: DispatchWorkItem(block: {
            self.socket?.close()
            self.socket = nil
        }))
        
    }
}

extension ViewController: NWAsyncSocketDelegate {
    
    func didConnect(socket: NWAsyncSocket) {
        print("\(socket) didConnect")
    }
    
    func didClose(socket: NWAsyncSocket) {
        print("\(socket) didClose")
    }
    
    func didFail(socket: NWAsyncSocket, error: any Error) {
        print("\(socket) didFail: \(error)")
    }
    
    func didReceiveData(socket: NWAsyncSocket, data: Data) {
        let msg = try? JSONSerialization.jsonObject(with: data)
        print("\(socket) didReceiveData: \(data), \(msg ?? "")")
    }
    
}

```

* oc:

```
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
    
    /// sync connect
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

```


## Installation

NWAsyncSocket is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'NWAsyncSocket'
```


## Author

jiang.feng, jiang.feng@trip.com

## License

NWAsyncSocket is available under the MIT license. See the LICENSE file for more info.
