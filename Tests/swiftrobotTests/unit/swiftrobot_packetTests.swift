//
//  swiftrobot_packetTests.swift
//
//
//  Created by Daniel Riege on 02.05.23.
//

import XCTest
@testable import swiftrobot
import BinaryCodable

final class swiftrobot_packetTests: XCTestCase {
    
    func testConnectPacket() throws {
        // create new message with data
        let msg = swiftrobot_packet_connect(name: "b", channels_to_subscribe: [0x1,0xff])
        XCTAssertEqual(msg.subscribes, 2)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x62, 0x00, 0x02, 0x00, 0x01, 0x00, 0xff, 0x00]) // size + data
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(swiftrobot_packet_connect.self, from: testData)
        XCTAssertEqual(testMsg.name, msg.name)
        XCTAssertEqual(testMsg.subscribes, msg.subscribes)
        XCTAssertEqual(testMsg.channels, msg.channels)
    }

}
