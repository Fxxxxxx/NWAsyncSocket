//
//  ViewController.swift
//  NWAsyncSocket
//
//  Created by jiang.feng on 09/13/2024.
//  Copyright (c) 2024 jiang.feng. All rights reserved.
//

import UIKit
import NWAsyncSocket

class ViewController: UIViewController {
    
    var socket: NWAsyncSocket?
    var ocTest: OCExample?
    
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
        
        ocTest = OCExample()
        ocTest?.run()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
