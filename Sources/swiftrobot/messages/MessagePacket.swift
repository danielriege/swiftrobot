import Foundation
import BinaryCodable

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX " : "%02hhx "
        return self.map { String(format: format, $0) }.joined()
    }
}


// base_msg
let UINT8ARRAY_MSG: UInt16      = 0x0001
let UINT16ARRAY_MSG: UInt16     = 0x0002
let UINT32ARRAY_MSG: UInt16     = 0x0003
let INT8ARRAY_MSG: UInt16       = 0x0004
let INT16ARRAY_MSG: UInt16      = 0x0005
let INT32ARRAY_MSG: UInt16      = 0x0006
let FLOATARRAY_MSG: UInt16      = 0x0007
// internal_msg
let UPDATE_MSG: UInt16          = 0x0101
// sensor_msg
let IMAGE_MSG: UInt16           = 0x0201
let IMU_MSG: UInt16             = 0x0202
// control_msg
let DRIVE_MSG: UInt16           = 0x0301
// nav_msg
let ODOMETRY_MSG: UInt16        = 0x0401

public protocol Message {
    func getType() -> UInt16
}

public typealias Msg = BinaryCodable & Message

// MARK: - SwiftRobotPackets

/**
 Base packet for all messages between swiftrobot clients. This would be the payload for a `swiftrobot_packet` with a `SwiftRobotPacketTypeMessage` type.
 */
struct MessagePacket: BinaryCodable {
    static let type_lookup_table: [UInt16: Msg.Type] = [
        UINT8ARRAY_MSG: base_msg.UInt8Array.self,
        UINT16ARRAY_MSG: base_msg.UInt16Array.self,
        UINT32ARRAY_MSG: base_msg.UInt32Array.self,
        INT8ARRAY_MSG: base_msg.Int8Array.self,
        INT16ARRAY_MSG: base_msg.Int16Array.self,
        INT32ARRAY_MSG: base_msg.Int32Array.self,
        FLOATARRAY_MSG: base_msg.FloatArray.self,
        UPDATE_MSG: internal_msgs.UpdateMsg.self,
        IMAGE_MSG: sensor_msg.Image.self,
        IMU_MSG: sensor_msg.IMU.self,
        DRIVE_MSG: control_msg.Drive.self,
        ODOMETRY_MSG: nav_msg.Odometry.self
    ]
    
    let channel: UInt16
    let type: UInt16
    let data_size: UInt32
    let data: Data
    
    init(channel: UInt16, type: UInt16, data_size: UInt32, data: Data) {
        self.channel = channel
        self.type = type
        self.data_size = data_size
        self.data = data
    }
    
    init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        channel = try container.decode(UInt16.self)
        type = try container.decode(UInt16.self)
        data_size = try container.decode(UInt32.self)
        data = try container.decode(length: Int(data_size))
    }
    
    func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        try container.encode(channel)
        try container.encode(type)
        try container.encode(data_size)
        try container.encode(sequence: data)
    }
}

