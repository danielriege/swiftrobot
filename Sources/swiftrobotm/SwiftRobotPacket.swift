//
//  File.swift
//  
//
//  Created by Daniel Riege on 21.09.22.
//

import Foundation
import BinaryCodable

enum swiftrobot_packet_protocol: UInt32, BinaryCodable {
    /**
     for swiftrobot packets
     
     - important: This was the binary usbmux protocol which is deprecated, so it will be resued as swiftrobot packets
     */
    case SwiftRobotPacketProtocol = 0
    /// used for usbmux communication
    case USBMuxPacketProtocol = 1
}

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
    case SwiftRobotPacketTypeMessage = 9
    case SwiftRobotPacketTypeSubscribeRequest = 10
    case SwiftRobotPacketTypeKeepAliveRequest = 11
    case SwiftRobotPacketTypeKeepAliveResponse = 12
}

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
