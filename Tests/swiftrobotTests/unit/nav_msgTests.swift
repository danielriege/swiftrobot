//
//  nav_msgTests.swift
//  
//
//  Created by Daniel Riege on 02.05.23.
//

import XCTest
import swiftrobot
import BinaryCodable

final class nav_msgTests: XCTestCase {

    func testOdometryMsg() throws {
        // create new message with data
        let msg = nav_msg.Odometry(positionX: 0.0, positionY: 1.0, positionZ: 0.0, roll: 0.0, pitch: 0.0, yaw: 1.0)
        XCTAssertEqual(msg.getType(), 0x0401)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3f])
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(nav_msg.Odometry.self, from: testData)
        XCTAssertEqual(testMsg.positionX, msg.positionX)
        XCTAssertEqual(testMsg.positionY, msg.positionY)
        XCTAssertEqual(testMsg.positionZ, msg.positionZ)
        XCTAssertEqual(testMsg.roll, msg.roll)
        XCTAssertEqual(testMsg.pitch, msg.pitch)
        XCTAssertEqual(testMsg.yaw, msg.yaw)
    }
}
