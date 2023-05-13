//
//  localCommTests.swift
//  
//
//  Created by Daniel Riege on 02.05.23.
//

import XCTest
import swiftrobot

final class oneClientMiddlewareTests: XCTestCase {
    
    private var client: SwiftRobotClient!
    private var timeout: TimeInterval = 0.001 // 1ms

    override func setUpWithError() throws {
        client = SwiftRobotClient()
    }

    func testPublishForget() throws {
        let pubMsg = base_msg.UInt8Array(data: [0xbe, 0xef])
        client.publish(channel: 0x01, msg: pubMsg)
        
        let expectation = XCTestExpectation(description: "Do not get message")
        expectation.isInverted = true
        client.subscribe(channel: 0x01) { (msg: base_msg.UInt8Array) in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }
    
    func testPublishRight() throws {
        let pubMsg = base_msg.UInt8Array(data: [0xbe, 0xef])
        
        let expectation = XCTestExpectation(description: "Do get message")
        client.subscribe(channel: 0x01) { (msg: base_msg.UInt8Array) in
            XCTAssertEqual(msg.size, pubMsg.size)
            XCTAssertEqual(msg.data, pubMsg.data)
            expectation.fulfill()
        }
        let expectation2 = XCTestExpectation(description: "Do not get message")
        expectation2.isInverted = true
        client.subscribe(channel: 0x01) { (msg: base_msg.UInt16Array) in
            expectation2.fulfill()
        }
        let expectation3 = XCTestExpectation(description: "Do not get message")
        expectation3.isInverted = true
        client.subscribe(channel: 0x02) { (msg: base_msg.UInt8Array) in
            expectation3.fulfill()
        }
        
        client.publish(channel: 0x01, msg: pubMsg)
        wait(for: [expectation, expectation2, expectation3], timeout: timeout)
    }
    
    func testSubscribeMultipleTimes() {
        let pubMsg = base_msg.UInt8Array(data: [0xbe, 0xef])
        
        let expectation1 = XCTestExpectation(description: "subscribe1")
        let expectation2 = XCTestExpectation(description: "subscribe2")
        client.subscribe(channel: 0x01) { (msg: base_msg.UInt8Array) in
            XCTAssertEqual(msg.size, pubMsg.size)
            XCTAssertEqual(msg.data, pubMsg.data)
            expectation1.fulfill()
        }
        client.subscribe(channel: 0x01) { (msg: base_msg.UInt8Array) in
            XCTAssertEqual(msg.size, pubMsg.size)
            XCTAssertEqual(msg.data, pubMsg.data)
            expectation2.fulfill()
        }
        
        client.publish(channel: 0x01, msg: pubMsg)
        wait(for: [expectation1, expectation2], timeout: timeout)
    }
}
