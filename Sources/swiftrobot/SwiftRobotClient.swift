//
//  Client.swift
//  
//
//  Created by Daniel Riege on 05.05.23.
//

import Foundation

public typealias SubscriberPriority = DispatchQoS.QoSClass

/**
 The `SwiftRobotClient` is a class that enables communication between robotic applications using a publish/subscribe IPC model. This means that messages can be distributed locally and to other clients on the same network.

 To set up the `SwiftRobotClient`, you don't need to manually interact with other clients on the network. Instead, the client will advertise its services on the network using bonjour, and a network of SwiftRobotClients will automatically form. To enable communication with other clients on the network, you just need to call the `start()` method. If you want to disconnect from all other clients and isolate this client, you can call the `stop()` method.

 To publish a message, you can use any channel in the `UInt16` range, except for channel 0, which is reserved for internal update messages (`internal_msg.UpdateMsg`). If you subscribe to channel 0, you will receive update information about other clients on the network. This can be particularly useful when a connection to a specific client is necessary for your application to operate safely.

 If you want to use custom message types, your message struct must conform to the `Msg` protocol, which means it must be `BinaryCodable` and implement the `getType()` method. The returned type must be unique.

 The `name` property is a global identifier for the client and should be unique on the local network. If you don't set a name, a UUID will be created.

 You can set an explicit `port` to be used, but if the application is restarted and a new client instance is created, the port might still be blocked, causing a delay of several seconds before connection to other clients is established. It's best not to set an explicit port unless necessary, such as when using firewalls.

 - important: for best performance, only one client per application should be used.
 */
public class SwiftRobotClient: ClientDispatcherDelegate {
    let queue = DispatchQueue(label: "com.swiftrobotm.client",
                                             qos: .userInitiated,
                                             attributes: .concurrent,
                                             autoreleaseFrequency: .workItem,
                                             target: .none)
    
    private var subscribersForChannel: [UInt16: [Subscriber]]
    private var clientDispatcher: ClientDispatcher
    private let name: String
    
    public init(name: String = UUID().uuidString, port: UInt16? = nil) {
        self.subscribersForChannel = [:]
        self.name = name
        self.clientDispatcher = ClientDispatcher(globalServiceName: name, port: port, queue: queue)
        self.clientDispatcher.delegate = self
    }
    
    public func start() {
        self.clientDispatcher.start()
    }
    
    public func stop() {
        self.clientDispatcher.stop()
    }
    
    /**
     Publish a message on a channel. Published messages are fire-and-forget.
     
     - parameters:
        - channel: the channel on which this message should be published
        - msg: the message to be published
     */
    public func publish(channel: UInt16, msg: Msg) {
        assert(channel != 0, "Cannot publish on channel 0")
        // local distribution
        notify(msg: msg, channel: channel)
        // external distribution
        clientDispatcher.dispatchMessage(channel: channel, msg: msg)
    }
    
    /**
     Subscribes to a channel with specific message type
     
     - parameter channel: Channel to which a subscription will be made
     - parameter queue_size: Setting the `queue_size` to 1, which is default, will mean that if a new message arrives while still in the callback for a previous message, the new message will be discarded. By increasing the `queue_size`, more callbacks can be processed at the same time (Use with caution).
     - parameter priority: If the application runs with full utilisation, the priority will determine which callback will be processed first in the global queue for all channels.
     - parameter callback: Will be called when a new message arrives. The parameter/message type must be explicitly defined.
     */
    public func subscribe<M: Msg>(channel: UInt16, priority: SubscriberPriority = .default, queue_size: Int = 1, callback: @escaping (M) -> Void) {
        if subscribersForChannel[channel] == nil {
            subscribersForChannel[channel] = []
        }
        let new_subscriber = Subscriber(callback: callback, priority: priority, queue_size: queue_size)
        subscribersForChannel[channel]!.append(new_subscriber)
        
        if channel != 0 {
            clientDispatcher.subscribeRequest(channel: channel)
        }
    }
    
    private func notify<M: Msg>(msg: M, channel: UInt16) {
        if subscribersForChannel[channel] != nil {
            for subscriber in subscribersForChannel[channel]! {
                // if last callback is not done, throw current round away
                if subscriber.semaphore.wait(timeout: .now()) == .timedOut {
                    continue
                }
                DispatchQueue.global(qos: subscriber.priority).async {
                    if let callback = subscriber.callback as? (M) -> Void  {
                        callback(msg)
                        subscriber.semaphore.signal()
                    } else {
                        print("Received wrong message type on channel \(channel)!")
                    }
                }
            }
        }
    }
    
    func didReceiveMessage(msg: Msg, channel: UInt16) {
        notify(msg: msg, channel: channel)
    }
    
}
