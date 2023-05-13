//
//  base_msg.swift
//  
//
//  Created by Daniel Riege on 09.05.22.
//

import Foundation
import BinaryCodable

public enum base_msg {}

public extension base_msg {
    struct UInt8Array: Msg {
        public let size: UInt32
        public let data: [UInt8]
        
        public func getType() -> UInt16 { return UINT8ARRAY_MSG}
        
        public init(data: [UInt8]) {
            self.data = data
            self.size = UInt32(data.count)
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            size = try container.decode(UInt32.self)
            data = Array(try container.decode(length: Int(size)))
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(size)
            try container.encode(sequence: Data(bytes: data, count: Int(size)))
        }
    }
    
    struct UInt16Array: Msg {
        public let size: UInt32
        public let data: [UInt16]
        
        public func getType() -> UInt16 { return UINT16ARRAY_MSG}
        
        public init(data: [UInt16]) {
            self.data = data
            self.size = UInt32(data.count * MemoryLayout<UInt16>.size)
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            size = try container.decode(UInt32.self)
            let data_flat = try container.decode(length: Int(size))
            data = data_flat.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: UInt16.self))
            }
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(size)
            try container.encode(sequence: Data(bytes: data, count: Int(size)))
        }
    }
    
    struct UInt32Array: Msg {
        public let size: UInt32
        public let data: [UInt32]
        
        public func getType() -> UInt16 { return UINT32ARRAY_MSG}
        
        public init(data: [UInt32]) {
            self.data = data
            self.size = UInt32(MemoryLayout<UInt32>.size * data.count)
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            size = try container.decode(UInt32.self)
            let data_flat = try container.decode(length: Int(size))
            data = data_flat.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: UInt32.self))
            }
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(size)
            try container.encode(sequence: Data(bytes: data, count: Int(size)))
        }
    }
    
    struct Int8Array: Msg {
        public let size: UInt32
        public let data: [Int8]
        
        public func getType() -> UInt16 { return INT8ARRAY_MSG}
        
        public init(data: [Int8]) {
            self.data = data
            self.size = UInt32(data.count)
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            size = try container.decode(UInt32.self)
            let data_flat = try container.decode(length: Int(size))
            data = data_flat.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Int8.self))
            }
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(size)
            try container.encode(sequence: Data(bytes: data, count: Int(size)))
        }
    }
    
    struct Int16Array: Msg {
        public let size: UInt32
        public let data: [Int16]
        
        public func getType() -> UInt16 { return INT16ARRAY_MSG}
        
        public init(data: [Int16]) {
            self.data = data
            self.size = UInt32(MemoryLayout<Int16>.size * data.count)
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            size = try container.decode(UInt32.self)
            let data_flat = try container.decode(length: Int(size))
            data = data_flat.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Int16.self))
            }
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(size)
            try container.encode(sequence: Data(bytes: data, count: Int(size)))
        }
    }
    
    struct Int32Array: Msg {
        public let size: UInt32
        public let data: [Int32]
        
        public func getType() -> UInt16 { return INT32ARRAY_MSG}
        
        public init(data: [Int32]) {
            self.data = data
            self.size = UInt32(MemoryLayout<Int32>.size * data.count)
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            size = try container.decode(UInt32.self)
            let data_flat = try container.decode(length: Int(size))
            data = data_flat.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Int32.self))
            }
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(size)
            try container.encode(sequence: Data(bytes: data, count: Int(size)))
        }
    }
    
    struct FloatArray: Msg {
        public let size: UInt32
        public let data: [Float64]
        
        public func getType() -> UInt16 { return FLOATARRAY_MSG}
        
        public init(data: [Float64]) {
            self.data = data
            self.size = UInt32(MemoryLayout<Float64>.size * data.count)
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            size = try container.decode(UInt32.self)
            let data_flat = try container.decode(length: Int(size))
            data = data_flat.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float64.self))
            }
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(size)
            try container.encode(sequence: Data(bytes: data, count: Int(size)))
        }
    }
}
