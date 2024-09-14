//
//  NWAsyncSocket.swift
//  NWAsyncSocket
//
//  Created by Aaron on 2024/9/13.
//

import Foundation
import Network

@objc public enum NWAsyncSocketType: Int {
    case TCP
    case UDP
    case TCPWithTLS
    case UDPWithDTLS
    @available(iOS 15.0, *) case QUIC
}

@objc public protocol NWAsyncSocketDelegate {
    func didConnect(socket: NWAsyncSocket)
    func didFail(socket: NWAsyncSocket, error:Error)
    func didClose(socket: NWAsyncSocket)
    func didReceiveData(socket: NWAsyncSocket, data: Data)
}

public extension NWAsyncSocketDelegate {
    func didConnect(socket: NWAsyncSocket) {}
    func didFail(socket: NWAsyncSocket, error:Error) {}
    func didClose(socket: NWAsyncSocket) {}
    func didReceiveData(socket: NWAsyncSocket, data: Data) {}
}

public typealias NWAsyncSocketConnectCompletion = ((Bool, Error?) -> ())

@objcMembers public class NWAsyncSocket: NSObject {
    
    public var tlsOptions: NWProtocolTLS.Options?
    public var protocolOptions: NWProtocolOptions?
    public let params: NWParameters
    
    private let connection: NWConnection
    private weak var delegate: NWAsyncSocketDelegate?
    private let delegateQueue: DispatchQueue
    private var timeoutTimer: DispatchSourceTimer?
    
    private let type: NWAsyncSocketType
    
    private let innerQueue: DispatchQueue
    private let innerQueueKey: DispatchSpecificKey<Int>
    
    private var connectCompletion: NWAsyncSocketConnectCompletion?
    
    public var state: NWConnection.State {
        connection.state
    }
    
    public init(host: String, port: UInt16, type: NWAsyncSocketType = .TCP, delegate: NWAsyncSocketDelegate? = nil, delegateQueue: DispatchQueue? = nil) {
        self.type = type
        self.delegate = delegate
        self.delegateQueue = delegateQueue ?? DispatchQueue.main
        innerQueue = .init(label: "com.queue.NWAsyncSocket")
        innerQueueKey = .init()
        
        switch type {
        case .TCP:
            let tcpOptions = NWProtocolTCP.Options.init()
            protocolOptions = tcpOptions
            params = .init(tls: .none, tcp: tcpOptions)
        case .UDP:
            let udpOptions = NWProtocolUDP.Options.init()
            protocolOptions = udpOptions
            params = .init(dtls: .none, udp: udpOptions)
        case .TCPWithTLS:
            let tcpOptions = NWProtocolTCP.Options.init()
            protocolOptions = tcpOptions
            tlsOptions = .init()
            params = .init(tls: tlsOptions, tcp: tcpOptions)
        case .UDPWithDTLS:
            let udpOptions = NWProtocolUDP.Options.init()
            protocolOptions = udpOptions
            tlsOptions = .init()
            params = .init(dtls: tlsOptions, udp: udpOptions)
        case .QUIC:
            if #available(iOS 15.0, *) {
                let quicOptions = NWProtocolQUIC.Options.init(alpn: [])
                params = .init(quic: quicOptions)
            } else {
                assert(false, "QUIC available iOS 15.0 !!!")
                protocolOptions = .none
                params = .init()
            }
        }
        connection = .init(host: .init(host), port: .init(integerLiteral: port), using: params)
        
        super.init()
        innerQueue.setSpecific(key: innerQueueKey, value: self.hash)
    }
    
    deinit {
        print("\(self) deinit.")
    }
    
    public func updateDelegate(delegate: NWAsyncSocketDelegate?) {
        runInInnerQueue {
            self.delegate = delegate
        }
    }
    
    private func runInInnerQueue(block: @escaping ()->()) {
        if DispatchQueue.getSpecific(key: innerQueueKey) == self.hash {
            block()
            return
        }
        innerQueue.async(execute: block)
    }
    
    public func connect(timeout: TimeInterval, completion: NWAsyncSocketConnectCompletion? = nil) {
        runInInnerQueue {
            if let tcpOptions = self.protocolOptions as? NWProtocolTCP.Options {
                tcpOptions.connectionTimeout = Int(timeout)
            }
            self.connection.stateUpdateHandler = { [weak self] state in
                self?.onConnectionStateChanged(state: state)
            }
            self.connectCompletion = completion
            self.startConnectTimeout(timeout: timeout)
            self.connection.start(queue: self.innerQueue)
        }
    }
    
    public func syncConnect(timeout: TimeInterval) -> Error? {
        let lock = NSConditionLock(condition: 1)
        var success = false
        var result: Error? = nil
        connect(timeout: timeout) { isSuccess, error in
            lock.lock(whenCondition: 1)
            success = isSuccess
            result = error
            lock.unlock(withCondition: 2)
        }
        lock.lock(whenCondition: 2, before: .init(timeIntervalSinceNow: timeout))
        if success == false && result == nil {
            result = NWError.posix(.ETIMEDOUT)
        }
        lock.unlock(withCondition: 1)
        return result
    }
    
    private func callbackConnectCompletion(isSuccess: Bool, error: Error?) {
        guard let completion = self.connectCompletion else { return }
        self.connectCompletion = nil;
        completion(isSuccess, error)
    }
    
    private func startConnectTimeout(timeout: TimeInterval) {
        self.stopConnectTimeout()
        timeoutTimer = DispatchSource.makeTimerSource(queue: innerQueue)
        timeoutTimer?.schedule(deadline: .now() + timeout, repeating: timeout, leeway: .milliseconds(0))
        timeoutTimer?.setEventHandler(handler: DispatchWorkItem(block: { [weak self] in
            self?.stopConnectTimeout()
            self?.onSocketDidFail(error: NWError.posix(.ETIMEDOUT))
            self?.close()
        }))
        timeoutTimer?.activate()
    }
    
    private func stopConnectTimeout() {
        guard let timer = timeoutTimer else { return }
        self.timeoutTimer = nil
        timer.cancel()
    }
    
    public func close() {
        runInInnerQueue { [self] in
            stopConnectTimeout()
            callbackConnectCompletion(isSuccess: false, error: nil)
            connection.cancel()
        }
    }
    
    /// send & receive
    
    private func startReceive() {
        self.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isDone, error in
            if let data = data, !data.isEmpty {
                self?.onSocketDidReceiveData(data: data)
            }
            if let error = error {
                self?.onSocketDidFail(error: error)
                self?.close()
                return
            }
            if isDone && (self?.type == .TCP || self?.type == .TCPWithTLS) {
                self?.close()
                return
            }
            self?.startReceive()
        }
    }
    
    public func send(data: Data, completion: ((Error?)->())?) {
        self.connection.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ [weak self] error in
            if let block = completion {
                self?.delegateQueue.async {
                    block(error)
                }
            }
            if let err = error {
                self?.onSocketDidFail(error: err)
                self?.close()
            }
        }));
    }
    
    /// socket state change
    
    private func onConnectionStateChanged(state: NWConnection.State) {
        switch state {
        case .ready:
            self.onSocketDidConnect()
        case .failed(let error):
            self.onSocketDidFail(error: error)
        case .cancelled:
            self.onSocketDidCancel()
        default:
            break
        }
    }
    
    private func onSocketDidConnect() {
        startReceive()
        stopConnectTimeout()
        callbackConnectCompletion(isSuccess: true, error: nil)
        guard let delegate = self.delegate else { return }
        delegateQueue.async {
            delegate.didConnect(socket: self)
        }
    }
    
    private func onSocketDidFail(error: NWError) {
        stopConnectTimeout()
        callbackConnectCompletion(isSuccess: false, error: error)
        guard let delegate = self.delegate else { return }
        delegateQueue.async {
            delegate.didFail(socket: self, error: error)
        }
    }
    
    private func onSocketDidCancel() {
        stopConnectTimeout()
        callbackConnectCompletion(isSuccess: false, error: nil)
        guard let delegate = self.delegate else { return }
        delegateQueue.async {
            delegate.didClose(socket: self)
        }
    }
    
    private func onSocketDidReceiveData(data: Data) {
        guard let delegate = self.delegate else { return }
        delegateQueue.async {
            delegate.didReceiveData(socket: self, data: data)
        }
    }
    
}
