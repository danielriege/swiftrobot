//
//  control_msg.swift
//  
//
//  Created by Daniel Riege on 09.05.22.
//

import Foundation
import BinaryCodable

public enum control_msg {}

public extension control_msg {
    struct Drive: Msg {
        public let throttle: Float
        public let brake: Float
        public let steer: Float
        public let reverse: UInt8
        
        public func getType() -> UInt16 { return DRIVE_MSG}
        
        public init(throttle: Float,
                    brake: Float,
                    steer: Float,
                    reverse: UInt8) {
            self.throttle = throttle
            self.brake = brake
            self.steer = steer
            self.reverse = reverse
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            throttle = try container.decode(Float.self)
            brake = try container.decode(Float.self)
            steer = try container.decode(Float.self)
            reverse = try container.decode(UInt8.self)
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(throttle)
            try container.encode(brake)
            try container.encode(steer)
            try container.encode(reverse)
        }
    }
}
