//
//  control_msgTests.swift
//  
//
//  Created by Daniel Riege on 02.05.23.
//

import XCTest
import swiftrobot
import BinaryCodable

final class control_msgTests: XCTestCase {

    func testDriveMsg() throws {
        // create new message with data
        let msg = control_msg.Drive(throttle: 0.5, brake: 0.0, steer: 1.0, reverse: 0)
        XCTAssertEqual(msg.getType(), 0x0301)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x00, 0x00, 0x00, 0x3f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3f, 0x00])
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(control_msg.Drive.self, from: testData)
        XCTAssertEqual(testMsg.throttle, msg.throttle)
        XCTAssertEqual(testMsg.brake, msg.brake)
        XCTAssertEqual(testMsg.steer, msg.steer)
        XCTAssertEqual(testMsg.reverse, msg.reverse)
    }

}
