import Foundation
import BinaryCodable

public typealias SubscriberPriority = DispatchQoS.QoSClass

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

public class SwiftRobotMaster {

    private lazy var subscribersForChannel: [UInt16: [Subscriber]] = [:]
    private var usbhub: Hub
    
    public init(port: UInt16) {
        self.usbhub = Hub(port: port)
        self.start()
    }
    
    public func publish<M: Msg>(channel: UInt16, msg: M) {
        // inform all internal subscribers on that topic
        publishInternal(channel: channel, msg: msg)
        // send message to external subscribers
        do {
            try self.sendMessage(channel: channel, msg: msg)
        } catch {
            // error
        }
    }
    
    public func publishInternal<M: Msg>(channel: UInt16, msg: M) {
        // inform all internal subscribers on that topic
        notify(msg, channel: channel)
    }
    
    public func subscribe<M>(channel: UInt16, callback: @escaping (M) -> Void, priority: SubscriberPriority = .default, queue_size: Int = 1) {
        if subscribersForChannel[channel] == nil {
            subscribersForChannel[channel] = []
        }
        let new_subscriber = Subscriber(callback: callback, priority: priority, queue_size: queue_size)
        subscribersForChannel[channel]!.append(new_subscriber)
    }
    
    private func start() {
        self.usbhub.registerRecieveCallback(callback: messageRecieved(data:))
        self.usbhub.registerStatusUpdateCallback { [self] deviceID, status in
            let statusUpdateMsg = internal_msgs.UpdateMsg(deviceID: deviceID, status: status)
            self.notify(statusUpdateMsg, channel: 0)
        }
        try! self.usbhub.startLookingForConnections()
    }
    
    private func messageRecieved(data: Data) {
        // deserialize message
        do {
            let packet = try BinaryDataDecoder().decode(SwiftRobotPacket.self, from: data)
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
            default:
                print("Received undefined message! ", packet.type, " on channel: ", packet.channel)
            }
        } catch {
            // error
            print("Unexpected error: \(error.localizedDescription).")
        }
    }
    
    private func notify<M: Msg>(_ msg: M, channel: UInt16) {
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
                        // wrong message type on channel
                    }
                }
            }
        }
    }
    
    private func sendMessage<M: Msg>(channel: UInt16, msg: M) throws {
        // serialize message
        let payload: Data = try BinaryDataEncoder().encode(msg)
        let packet = SwiftRobotPacket(channel: channel, type: msg.getType(), data_size: UInt32(payload.count), data: payload)
        let packet_data: Data = try BinaryDataEncoder().encode(packet)
        
        // send message
        self.usbhub.sendPacketToAll(packet_data)
    }
}
