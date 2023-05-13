//
//  File.swift
//  
//
//  Created by Daniel Riege on 21.09.22.
//

import Foundation
import BinaryCodable

/**
 Protocol type of a swiftrobot packet. For Swift clients only `SwiftRobotPacketProtocol` will be used. Since the structure of a swiftrobot packet comes from usbmux packets, a swiftrobot packet can also be used to communicate with usbmux using the `USBMuxPacketProtocol` protocol type. It will only be used on a C++ swiftrobot client to use USB connections.
 
 - important: Originally the `SwiftRobotPacketProtocol` was the binary protocol of usbmux which is deprecated to this type will be reused as `SwiftRobotPacketProtocol`.
 */
enum swiftrobot_packet_protocol: UInt32, BinaryCodable {
    case SwiftRobotPacketProtocol = 0
    case USBMuxPacketProtocol = 1
}

/**
 Type of a swiftrobot packet.
 
 If using the `SwiftRobotPacketProtocol` protocol only the `SwiftRobotPacketType` should be used. When using the `USBMuxPacketProtocol` only the `UBSMUxPacketType` should be used.
 */
enum swiftrobot_packet_type: UInt32, BinaryCodable {
    // Deprecated binary usbmux protocol types
    case USBMuxPacketTypeResult = 1
    case USBMuxPacketTypeConnect = 2
    case USBMuxPacketTypeListen = 3
    case USBMuxPacketTypeDeviceAdd = 4
    case USBMuxPacketTypeDeviceRemove = 5
    // ? = 6,
    // ? = 7,
    case USBMuxPacketTypePlistPayload = 8 // only supported type by usbmuxd by now
    // Custom Types
    /// for messages like base_msgs. Paylod must be a message packet
    case SwiftRobotPacketTypeMessage = 9
    /// subscribe request to let the peer know what channels should be distributed
    case SwiftRobotPacketTypeSubscribeRequest = 10
    /// check if peer is still alive
    case SwiftRobotPacketTypeKeepAliveRequest = 11
    /// Reply to a keep alive request
    case SwiftRobotPacketTypeKeepAliveResponse = 12
    /// connection request. Should be sent right after a connection is established. Payload must be a `swiftrobot_packet_connect`
    case SwiftRobotPacketTypeConnect = 13
    /// reply to a connection request. Payload must be a `swiftrobot_packet_connect`
    case SwiftRobotPacketTypeConnectAck = 14
}

/**
 The base layer packet which is sent via TCP to other swiftrobot clients.
 
 Every message that is being sent between swiftrobot clients must be of the packet. The Payload will depend on the `type` which on the other hand will depend on the `swiftrobot_protocol`.
 
 - important: the `tag` is not used between swiftrobot clients but when a swiftrobot client communicates with a usbmux daemon.
 */
struct swiftrobot_packet: BinaryCodable {
    let length: UInt32
    let swiftrobot_protocol: swiftrobot_packet_protocol
    let type: swiftrobot_packet_type
    let tag: UInt32
    let payload: Data
    
    init(swiftrobot_protocol: swiftrobot_packet_protocol, type: swiftrobot_packet_type, tag: UInt32, payload: Data) {
        self.length = UInt32(16 + payload.count)
        self.swiftrobot_protocol = swiftrobot_protocol
        self.type = type
        self.tag = tag
        self.payload = payload
    }
    
    init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        self.length = try container.decode(UInt32.self)
        
        var protocolContainer = container.nestedContainer(maxLength: 4) // uint32_t is 4 bytes
        self.swiftrobot_protocol = try protocolContainer.decode(swiftrobot_packet_protocol.self)
        
        var typeContainer = container.nestedContainer(maxLength: 4) // uint32_t is 4 bytes
        self.type = try typeContainer.decode(swiftrobot_packet_type.self)
        
        self.tag = try container.decode(UInt32.self)
        self.payload = try container.decode(length: Int(self.length - 16)) // previous types are 16 bytes in total
    }
    
    func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        try container.encode(length)
        try container.encode(swiftrobot_protocol)
        try container.encode(type)
        try container.encode(tag)
        try container.encode(sequence: payload)
    }
}

/**
 This is a payload for a `swiftrobot_packet` with a `SwiftRobotPacketTypeConnect` or `SwiftRobotPacketTypeConnectAck` type.
 */
struct swiftrobot_packet_connect: BinaryCodable {
    let name: String
    let subscribes: UInt16
    let channels: [UInt16]
    
    init(name: String, channels_to_subscribe: [UInt16]) {
        self.name = name
        self.subscribes = UInt16(channels_to_subscribe.count)
        self.channels = channels_to_subscribe
    }
    
    init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        name = try container.decodeString(encoding: .utf8, terminator: 0)
        subscribes = try container.decode(UInt16.self)
        let data_flat = try container.decode(length: Int(subscribes) * MemoryLayout<UInt16>.size)
        channels = data_flat.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: UInt16.self))
        }
    }
    
    func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        try container.encode(name, encoding: .utf8, terminator: 0)
        try container.encode(subscribes)
        try container.encode(sequence: Data(bytes: channels, count: Int(subscribes) * MemoryLayout<UInt16>.size))
    }
}
