import Foundation
import BinaryCodable

public enum ConnectionType {
    case none
    case usb
}

public class SwiftRobotMaster {

    private var connectionType: ConnectionType = .none
    private lazy var channel_subscriber_map: [UInt16: [Any]] = [:]
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
    
    public func subscribe<M>(channel: UInt16, callback: @escaping (M) -> Void) {
        if channel_subscriber_map[channel] == nil {
            channel_subscriber_map[channel] = []
        }
        channel_subscriber_map[channel]!.append(callback)
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
        if channel_subscriber_map[channel] != nil {
            for subscriber_callback in channel_subscriber_map[channel]! {
                if let callback = subscriber_callback as? (M) -> Void  {
                    callback(msg)
                } else {
                    // wrong message type on channel
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
