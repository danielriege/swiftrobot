//
//  sensor_msgTests.swift
//  
//
//  Created by Daniel Riege on 02.05.23.
//

import XCTest
import swiftrobot
import BinaryCodable

final class sensor_msgTests: XCTestCase {

    func testImageMsg() throws {
        // create new message with data
        let msg = sensor_msg.Image(width: 2, height: 1, pixelFormat: .RGBA, data: [0xbe, 0xef])
        XCTAssertEqual(msg.getType(), 0x0201)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x02, 0x00, 0x01, 0x00, 0x42, 0x47, 0x52, 0x41, 0x02, 0x00, 0x00, 0x00, 0xbe, 0xef]) // last 3 bytes are size and data for uint8 array
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(sensor_msg.Image.self, from: testData)
        XCTAssertEqual(msg.width, testMsg.width)
        XCTAssertEqual(msg.height, testMsg.height)
        XCTAssertEqual(msg.pixelFormat, testMsg.pixelFormat)
        XCTAssertEqual(msg.pixelArray.size, testMsg.pixelArray.size)
        XCTAssertEqual(msg.pixelArray.data, testMsg.pixelArray.data)
    }
}
