import Foundation
import BinaryCodable

public typealias SubscriberPriority = DispatchQoS.QoSClass

/**
Information about a subscription for a specific channel
 */
 struct Subscriber {
    let callback: Any
    let priority: SubscriberPriority
    let queue_size: Int
    let semaphore: DispatchSemaphore
    
    init(callback: Any, priority: SubscriberPriority, queue_size: Int) {
        self.callback = callback
        self.priority = priority
        self.queue_size = queue_size
        self.semaphore = DispatchSemaphore(value: queue_size)
    }
}

/**
 Information about an external connection
 */
struct ExternalClient {
    let deviceID: UInt8
    var lastKeepAliveResponse: DispatchTime
    var subscriptions = [UInt16]()
}

/**
 Dispatches published messages internally and externally depending on subscriptions
 
 - Important: There should only be one Master in the whole system
 
 Upon creation, the master only dispatches messages locally. To start the server for external communication, execute the start() method.
 
 It is best practice to only make a subscribe on channel 0, which is for status messages about external devices, before the start() method.
 */
public class SwiftRobotMaster {
    private static let queue = DispatchQueue(label: "com.swiftrobotm.comm",
                                             qos: .userInitiated,
                                             attributes: .concurrent,
                                             autoreleaseFrequency: .workItem,
                                             target: .none)
    private static let keepAliveTimeout: Double = 5.0 // seconds
    private static let keepAliveDelay: Double = 2.0 // seconds
    private static let keepAliveCheckTimer: Double = 0.5 // seconds

    private var subscribersForChannel: [UInt16: [Subscriber]] = [:]
    private var externalClients = [UInt8: ExternalClient]()
    private var server: Server
    
    /**
     Creates a new master instance
     
     - parameters:
        - port: Optional if a different listening port should be used
     */
    public init(port: UInt16) {
        self.server = Server(port: port, queue: SwiftRobotMaster.queue)
    }
    
    /**
     Publish a message to external devices, in case they have subscribed to it, and dispatches it to local subscribers.
     
     - parameters:
        - channel: channel on which the message will be dispatched
        - msg: message to dispatch
     */
    public func publish<M: Msg>(channel: UInt16, msg: M) {
        // inform all internal subscribers on that topic
        notify(msg, channel: channel)
        // send message to external clients if they have subsrcibed to that channel
        print("send")
        for eClient in externalClients.values {
            if eClient.subscriptions.contains(channel) {
                do {
                    try self.sendMessage(device: eClient.deviceID,channel: channel, msg: msg)
                } catch {
                    
                }
            }
        }
    }
    
    /**
    Publish a message to local subscribers only.
     
     - parameters:
        - channel: channel on which the message will be dispatched
        - msg: message to dispatch
     
     - important: To publish the message to externa subscribers as well, the message needs to conform to the Msg protocol
     */
    public func publish<M>(channel: UInt16, msg: M) {
        // inform all internal subscribers on that topic
        notify(msg, channel: channel)
    }
    
    /**
     Make a new subscribe on a channel with a specific message type
     
     - parameters:
        - channel: channel on which to subscribe
        - callback: function with message of specific type as parameter which is called when a new message arrived
        - priority: (Optional) Priority of the subscriber on the DispatchQueue
        - queue_size: (Optional) buffer size for incoming messages. Default to 1 discards messages arrived late
     */
    public func subscribe<M>(channel: UInt16, callback: @escaping (M) -> Void, priority: SubscriberPriority = .default, queue_size: Int = 1) {
        if subscribersForChannel[channel] == nil {
            subscribersForChannel[channel] = []
        }
        let new_subscriber = Subscriber(callback: callback, priority: priority, queue_size: queue_size)
        subscribersForChannel[channel]!.append(new_subscriber)
    }
    
    /**
    Starts Server for external communication
     */
    public func start() {
        self.server.registerPacketReceivedCallback(callback: multiplexIncomingPacket(deviceID:type:data:))
        self.server.registerStatusUpdateCallback(callback: clientStatusUpdate(deviceID:status:))
        try! self.server.startLookingForConnections()
        self.startKeepAliveCheckCycle()
    }
    
    // MARK: - Callbacks
    
    /// called on any kind of external client status update
    private func clientStatusUpdate(deviceID: UInt8, status: internal_msgs.UpdateMsg.status_t) {
        if status == .connected {
            externalClients[deviceID] = ExternalClient(deviceID: deviceID, lastKeepAliveResponse: .now())
            // start with keep alive cycle
            self.sendKeepAliveAfterDelay(device: deviceID)
        } else if status == .disconnected {
            externalClients.removeValue(forKey: deviceID)
        }
        let statusUpdateMsg = internal_msgs.UpdateMsg(deviceID: deviceID, status: status)
        self.notify(statusUpdateMsg, channel: 0)
    }
    
    private func multiplexIncomingPacket(deviceID: UInt8, type: swiftrobot_packet_type, data: Data) {
        switch type {
        case .USBMuxPacketTypeResult: break
        case .USBMuxPacketTypeConnect: break
        case .USBMuxPacketTypeListen: break
        case .USBMuxPacketTypeDeviceAdd: break
        case .USBMuxPacketTypeDeviceRemove: break
        case .USBMuxPacketTypePlistPayload: break
        case .SwiftRobotPacketTypeMessage:
            self.messageRecieved(deviceID: deviceID, data: data)
        case .SwiftRobotPacketTypeSubscribeRequest:
            self.newSubscribeRequest(deviceID: deviceID, data: data)
        case .SwiftRobotPacketTypeKeepAliveRequest:
            break
        case .SwiftRobotPacketTypeKeepAliveResponse:
            self.handleKeepAliveResponse(deviceID: deviceID)
        }
    }
    
    // MARK: - Packet Handling
    
    private func handleKeepAliveResponse(deviceID: UInt8) {
        if externalClients[deviceID] != nil {
            externalClients[deviceID]?.lastKeepAliveResponse = .now()
            // send new request to keep cycle alive
            self.sendKeepAliveAfterDelay(device: deviceID)
        }
    }
    
    private func newSubscribeRequest(deviceID: UInt8, data: Data) {
        // for subscribe request we dont need a packet since its only a UInt16
        print("got subscri")
        data.withUnsafeBytes { buffer in
            let channelToSubscribe = buffer.load(as: UInt16.self)
            if self.externalClients[deviceID] != nil {
                self.externalClients[deviceID]!.subscriptions.append(channelToSubscribe)
            }
        }
    }
    
    private func messageRecieved(deviceID: UInt8, data: Data) {
        // deserialize message
        do {
            let packet = try BinaryDataDecoder().decode(MessagePacket.self, from: data)
            switch packet.type {
            // base_msg
            case UINT8ARRAY_MSG: notify(try BinaryDataDecoder().decode(base_msg.UInt8Array.self, from: packet.data), channel: packet.channel)
            case UINT16ARRAY_MSG: notify(try BinaryDataDecoder().decode(base_msg.UInt16Array.self, from: packet.data), channel: packet.channel)
            case UINT32ARRAY_MSG: notify(try BinaryDataDecoder().decode(base_msg.UInt32Array.self, from: packet.data), channel: packet.channel)
            case INT8ARRAY_MSG: notify(try BinaryDataDecoder().decode(base_msg.Int8Array.self, from: packet.data), channel: packet.channel)
            case INT16ARRAY_MSG: notify(try BinaryDataDecoder().decode(base_msg.Int16Array.self, from: packet.data), channel: packet.channel)
            case INT32ARRAY_MSG: notify(try BinaryDataDecoder().decode(base_msg.Int32Array.self, from: packet.data), channel: packet.channel)
            case FLOATARRAY_MSG: notify(try BinaryDataDecoder().decode(base_msg.FloatArray.self, from: packet.data), channel: packet.channel)
            // sensor_msg
            case IMAGE_MSG: notify(try BinaryDataDecoder().decode(sensor_msg.Image.self, from: packet.data), channel: packet.channel)
            case IMU_MSG: notify(try BinaryDataDecoder().decode(sensor_msg.IMU.self, from: packet.data), channel: packet.channel)
            // control_msg
            case DRIVE_MSG: notify(try BinaryDataDecoder().decode(control_msg.Drive.self, from: packet.data), channel: packet.channel)
            // nav_msg
            case ODOMETRY_MSG: notify(try BinaryDataDecoder().decode(nav_msg.Odometry.self, from: packet.data), channel: packet.channel)
            default:
                print("Received undefined message! ", packet.type, " on channel: ", packet.channel)
            }
        } catch {
            // error
            print("Unexpected error: \(error.localizedDescription).")
        }
    }
    
    // MARK: - Helper
    
    private func notify<M>(_ msg: M, channel: UInt16) {
        if subscribersForChannel[channel] != nil {
            for subscriber in subscribersForChannel[channel]! {
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
    
    private func sendMessage<M: Msg>(device: UInt8, channel: UInt16, msg: M) throws {
        // serialize message
        let payload: Data = try BinaryDataEncoder().encode(msg)
        let packet = MessagePacket(channel: channel, type: msg.getType(), data_size: UInt32(payload.count), data: payload)
        let packet_data: Data = try BinaryDataEncoder().encode(packet)
        
        // send message
        self.server.sendPacket(to: Int(device), data: packet_data, type: .SwiftRobotPacketTypeMessage)
    }
    
    private func startKeepAliveCheckCycle() {
        DispatchQueue.global().asyncAfter(deadline: .now() + SwiftRobotMaster.keepAliveCheckTimer) {
            for device in self.externalClients.keys {
                _ = self.checkKeepAlive(device: device)
            }
            if self.server.running {
                self.startKeepAliveCheckCycle()
            }
        }
    }
    
    private func checkKeepAlive(device: UInt8) -> Bool {
        if externalClients[device] != nil &&
            externalClients[device]!.lastKeepAliveResponse + SwiftRobotMaster.keepAliveTimeout < .now() {
            print("Device \(device) timed out...")
            self.server.disconnectToDevice(deviceID: Int(device))
            // removal from dict is done automatically after successfull disconnect
            return false
        }
        return true
    }
    
    private func sendKeepAliveAfterDelay(device: UInt8) {
        DispatchQueue.global().asyncAfter(deadline: .now()+SwiftRobotMaster.keepAliveDelay) {
            self.server.sendPacket(to: Int(device), data: Data(), type: .SwiftRobotPacketTypeKeepAliveRequest)
        }
    }
}
