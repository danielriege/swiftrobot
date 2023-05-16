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
    
    func testSubscribeOverload() {
        let pubMsg = base_msg.UInt8Array(data: [1])
        let pubMsg2 = base_msg.UInt8Array(data: [2])
        
        let expectation = XCTestExpectation(description: "subscribe")
        let expectationNot = XCTestExpectation(description: "subscribe not triggered")
        expectationNot.isInverted = true
        
        let expectationDummy = XCTestExpectation(description: "dummy")
        expectationDummy.isInverted = true
        
        client.subscribe(channel: 0x01) { (msg: base_msg.UInt8Array) in
            self.wait(for: [expectationDummy], timeout: 0.1)
            if msg.data[0] == 1 {
                XCTAssertEqual(msg.size, pubMsg.size)
                XCTAssertEqual(msg.data, pubMsg.data)
                expectation.fulfill()
            } else {
                expectationNot.fulfill()
            }
        }
        client.publish(channel: 0x01, msg: pubMsg)
        client.publish(channel: 0x01, msg: pubMsg2)
        
        wait(for: [expectation, expectationNot], timeout: 1)
    }
    
    func testSubscribeOverloadButQueueBigger() {
        let pubMsg = base_msg.UInt8Array(data: [1])
        let pubMsg2 = base_msg.UInt8Array(data: [2])
        
        let expectation = XCTestExpectation(description: "subscribe")
        let expectation2 = XCTestExpectation(description: "subscribe2")
        
        let expectationDummy = XCTestExpectation(description: "dummy")
        expectationDummy.isInverted = true
        let expectationDummy2 = XCTestExpectation(description: "dummy")
        expectationDummy2.isInverted = true
        
        client.subscribe(channel: 0x01, queue_size: 2) { (msg: base_msg.UInt8Array) in
            if msg.data[0] == 1 {
                self.wait(for: [expectationDummy], timeout: 0.1)
                XCTAssertEqual(msg.size, pubMsg.size)
                XCTAssertEqual(msg.data, pubMsg.data)
                expectation.fulfill()
            } else {
                self.wait(for: [expectationDummy2], timeout: 0.1)
                XCTAssertEqual(msg.size, pubMsg2.size)
                XCTAssertEqual(msg.data, pubMsg2.data)
                expectation2.fulfill()
            }
        }
        client.publish(channel: 0x01, msg: pubMsg)
        client.publish(channel: 0x01, msg: pubMsg2)
        
        wait(for: [expectation, expectation2], timeout: 1)
    }
}
