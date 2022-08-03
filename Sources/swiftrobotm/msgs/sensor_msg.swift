//
//  sensor_msg.swift
//  
//
//  Created by Daniel Riege on 09.05.22.
//

import Foundation
import BinaryCodable

public enum sensor_msg {}

public extension sensor_msg {
    
    struct Image: Msg {
        public enum pixelFormat_t: String, BinaryCodable {
            case YCrCb420v  = "420v"
            case YCrCb420f  = "420f"
            case RGBA       = "BGRA"
            case Mono       = "MONO"
        }
        
        public let width: UInt16
        public let height: UInt16
        public let pixelFormat: pixelFormat_t
        public let pixelArray: base_msg.UInt8Array
        
        public func getType() -> UInt16 { return IMAGE_MSG}
        
        public init(width: UInt16, height: UInt16, pixelFormat: pixelFormat_t, data: [UInt8]) {
            self.width = width
            self.height = height
            self.pixelFormat = pixelFormat
            self.pixelArray = base_msg.UInt8Array(data: data)
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            width = try container.decode(UInt16.self)
            height = try container.decode(UInt16.self)
            var pixelFormatContainer = container.nestedContainer(maxLength: 4)
            pixelFormat = try pixelFormatContainer.decode(pixelFormat_t.self)
            pixelArray = try container.decode(base_msg.UInt8Array.self)
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(width)
            try container.encode(height)
            try container.encode(pixelFormat)
            try container.encode(pixelArray)
        }
    }
    
    struct IMU: Msg {
        public let orientationX: Float
        public let orientationY: Float
        public let orientationZ: Float
        
        public let angularVelocityX: Float
        public let angularVelocityY: Float
        public let angularVelocityZ: Float
        
        public let linearAccelerationX: Float
        public let linearAccelerationY: Float
        public let linearAccelerationZ: Float
        
        public func getType() -> UInt16 { return IMU_MSG}
        
        public init(orientationX: Float,
                    orientationY: Float,
                    orientationZ: Float,
                    angularVelocityX: Float,
                    angularVelocityY: Float,
                    angularVelocityZ: Float,
                    linearAccelerationX: Float,
                    linearAccelerationY: Float,
                    linearAccelerationZ: Float) {
            self.orientationX = orientationX
            self.orientationY = orientationY
            self.orientationZ = orientationZ
            self.angularVelocityX = angularVelocityX
            self.angularVelocityY = angularVelocityY
            self.angularVelocityZ = angularVelocityZ
            self.linearAccelerationX = linearAccelerationX
            self.linearAccelerationY = linearAccelerationY
            self.linearAccelerationZ = linearAccelerationZ
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            orientationX = try container.decode(Float.self)
            orientationY = try container.decode(Float.self)
            orientationZ = try container.decode(Float.self)
            angularVelocityX = try container.decode(Float.self)
            angularVelocityY = try container.decode(Float.self)
            angularVelocityZ = try container.decode(Float.self)
            linearAccelerationX = try container.decode(Float.self)
            linearAccelerationY = try container.decode(Float.self)
            linearAccelerationZ = try container.decode(Float.self)
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(orientationX)
            try container.encode(orientationY)
            try container.encode(orientationZ)
            try container.encode(angularVelocityX)
            try container.encode(angularVelocityY)
            try container.encode(angularVelocityZ)
            try container.encode(linearAccelerationX)
            try container.encode(linearAccelerationY)
            try container.encode(linearAccelerationZ)
        }
    }
}
