//
//  base_msgTests.swift
//  
//
//  Created by Daniel Riege on 02.05.23.
//

import XCTest
import swiftrobot
import BinaryCodable

final class base_msgTests: XCTestCase {

    func testUInt8Array() throws {
        // create new message with data
        let msg = base_msg.UInt8Array(data: [0xbe, 0xef])
        XCTAssertEqual(msg.getType(), 0x0001)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x02, 0x00, 0x00, 0x00, 0xbe, 0xef]) // size + data
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(base_msg.UInt8Array.self, from: testData)
        XCTAssertEqual(testMsg.data, msg.data)
        XCTAssertEqual(testMsg.size, msg.size)
    }
    
    func testUInt16Array() throws {
        // create new message with data
        let msg = base_msg.UInt16Array(data: [0x00be, 0xffef])
        XCTAssertEqual(msg.getType(), 0x0002)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x04, 0x00, 0x00, 0x00, 0xbe, 0x00, 0xef, 0xff]) // size + data
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(base_msg.UInt16Array.self, from: testData)
        XCTAssertEqual(testMsg.data, msg.data)
        XCTAssertEqual(testMsg.size, msg.size)
    }
    
    func testUInt32Array() throws {
        // create new message with data
        let msg = base_msg.UInt32Array(data: [0x00be, 0xbb00ffef])
        XCTAssertEqual(msg.getType(), 0x0003)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x08, 0x00, 0x00, 0x00, 0xbe, 0x00, 0x00, 0x00, 0xef, 0xff, 0x00, 0xbb]) // size + data
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(base_msg.UInt32Array.self, from: testData)
        XCTAssertEqual(testMsg.data, msg.data)
        XCTAssertEqual(testMsg.size, msg.size)
    }
    
    func testInt8Array() throws {
        // create new message with data
        let msg = base_msg.Int8Array(data: [0x0f, -31])
        XCTAssertEqual(msg.getType(), 0x0004)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x02, 0x00, 0x00, 0x00, 0x0f, 0xe1]) // size + data
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(base_msg.Int8Array.self, from: testData)
        XCTAssertEqual(testMsg.data, msg.data)
        XCTAssertEqual(testMsg.size, msg.size)
    }
    
    func testInt16Array() throws {
        // create new message with data
        let msg = base_msg.Int16Array(data: [0x00be, -3100])
        XCTAssertEqual(msg.getType(), 0x0005)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x04, 0x00, 0x00, 0x00, 0xbe, 0x00, 0xe4, 0xf3]) // size + data
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(base_msg.Int16Array.self, from: testData)
        XCTAssertEqual(testMsg.data, msg.data)
        XCTAssertEqual(testMsg.size, msg.size)
    }
    
    func testInt32Array() throws {
        // create new message with data
        let msg = base_msg.Int32Array(data: [0x00be, -3100])
        XCTAssertEqual(msg.getType(), 0x0006)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x08, 0x00, 0x00, 0x00, 0xbe, 0x00, 0x00, 0x00, 0xe4, 0xf3, 0xff, 0xff]) // size + data
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(base_msg.Int32Array.self, from: testData)
        XCTAssertEqual(testMsg.data, msg.data)
        XCTAssertEqual(testMsg.size, msg.size)
    }
    
    func testFloatArray() throws {
        // create new message with data
        let msg = base_msg.FloatArray(data: [3.41,])
        XCTAssertEqual(msg.getType(), 0x0007)
        let binaryMsg: Data = try BinaryDataEncoder().encode(msg)
        // test with raw expected bytes
        let testData = Data([0x08, 0x00, 0x00, 0x00, 0x48, 0xe1, 0x7a, 0x14, 0xae, 0x47, 0x0b, 0x40]) // size + data
        XCTAssertEqual(binaryMsg, testData)
        // create msg object from raw data
        let testMsg = try BinaryDataDecoder().decode(base_msg.FloatArray.self, from: testData)
        XCTAssertEqual(testMsg.data, msg.data)
        XCTAssertEqual(testMsg.size, msg.size)
    }

}
