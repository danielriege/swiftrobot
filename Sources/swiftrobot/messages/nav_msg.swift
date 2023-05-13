//
//  File.swift
//  
//
//  Created by Daniel Riege on 03.08.22.
//

import Foundation

import BinaryCodable

public enum nav_msg {}

public extension nav_msg {
    
    struct Odometry: Msg {
        public let positionX: Float
        public let positionY: Float
        public let positionZ: Float
        
        public let roll: Float
        public let pitch: Float
        public let yaw: Float
        
        public func getType() -> UInt16 { return ODOMETRY_MSG}
        
        public init(positionX: Float,
                    positionY: Float,
                    positionZ: Float,
                    roll: Float,
                    pitch: Float,
                    yaw: Float) {
            self.positionX = positionX
            self.positionY = positionY
            self.positionZ = positionZ
            self.roll = roll
            self.pitch = pitch
            self.yaw = yaw
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            positionX = try container.decode(Float.self)
            positionY = try container.decode(Float.self)
            positionZ = try container.decode(Float.self)
            roll = try container.decode(Float.self)
            pitch = try container.decode(Float.self)
            yaw = try container.decode(Float.self)
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(positionX)
            try container.encode(positionY)
            try container.encode(positionZ)
            try container.encode(roll)
            try container.encode(pitch)
            try container.encode(yaw)
        }
    }
}
