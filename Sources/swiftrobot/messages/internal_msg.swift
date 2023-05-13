//
//  File.swift
//  
//
//  Created by Daniel Riege on 05.05.23.
//

import Foundation
import BinaryCodable

public enum internal_msgs {}

public extension internal_msgs {
    
    struct UpdateMsg: Msg {
        public enum status_t: UInt8, BinaryCodable {
            case connected = 0
            case disconnected = 1
        }
        
        public let clientID: String
        public let status: status_t
        
        public func getType() -> UInt16 {return UPDATE_MSG}
        
        public init(clientID: String, status: status_t) {
            self.clientID = clientID
            self.status = status
        }
        
        public init(from decoder: BinaryDecoder) throws {
            var container = decoder.container(maxLength: nil)
            clientID = try container.decodeString(encoding: .utf8, terminator: 0)
            var statusContainer = container.nestedContainer(maxLength: 1)
            status = try statusContainer.decode(status_t.self)
        }
        
        public func encode(to encoder: BinaryEncoder) throws {
            var container = encoder.container()
            try container.encode(clientID, encoding: .utf8, terminator: 0)
            try container.encode(status)
        }
    }
}
