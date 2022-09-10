//
//  File.swift
//  
//
//  Created by Daniel Riege on 10.09.22.
//

import Foundation

import BinaryCodable

public enum state_msg {}

public extension state_msg {
    
    struct VescStatus: Msg {
        public let mosfetTemp: Float;
        public let motorTemp: Float;
        public let rpm: Int32;
        public let batteryVoltage: Float;
        public let tachometer: Int32;
        public let tachometerAbs: Int32;
        
        public func getType() -> UInt16 { return VESCSTATUS_MSG}
        
        public init(mosfetTemp: Float,
                    motorTemp: Float,
                    rpm: Int32,
                    batteryVoltage: Float,
                    tachometer: Int32,
                    tachometerAbs: Int32) {
            self.mosfetTemp = mosfetTemp
            self.motorTemp = motorTemp
            self.rpm = rpm
            self.batteryVoltage = batteryVoltage
            self.tachometer = tachometer
            self.tachometerAbs = tachometerAbs
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            mosfetTemp = try container.decode(Float.self)
            motorTemp = try container.decode(Float.self)
            rpm = try container.decode(Int32.self)
            batteryVoltage = try container.decode(Float.self)
            tachometer = try container.decode(Int32.self)
            tachometerAbs = try container.decode(Int32.self)
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(mosfetTemp)
            try container.encode(motorTemp)
            try container.encode(rpm)
            try container.encode(batteryVoltage)
            try container.encode(tachometer)
            try container.encode(tachometerAbs)
        }
    }
}
