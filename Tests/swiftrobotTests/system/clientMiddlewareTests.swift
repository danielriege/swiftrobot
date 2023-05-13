//
//  clientMiddlewareTests.swift
//  
//
//  Created by Daniel Riege on 10.05.23.
//

import XCTest
import swiftrobot

final class clientMiddlewareTests: XCTestCase {
    
    private var clientA_: SwiftRobotClient!
    private var clientB_: SwiftRobotClient!
    
    private let largeMessageSize: Int = 40_000_000 // 40 MB

    override func setUp() {
        clientA_ = SwiftRobotClient(name: "clientA")
        clientB_ = SwiftRobotClient(name: "clientB")
    }

    override func tearDown() {
        clientA_.stop()
        clientB_.stop()
    }
    
    func testSubscribeBeforeStart() throws {
        let expectationA = XCTestExpectation(description: "client A receives message from B")
        
        let msg_array = Array<UInt8>(repeating: 0xef, count: 2)
        let msg = base_msg.UInt8Array(data: msg_array)
        
        clientA_.subscribe(channel: 0x01, callback: { (msg: base_msg.UInt8Array) in
            if msg.size != 2 {
                XCTAssertFalse(true)
            }
            expectationA.fulfill()
        })
        
        clientA_.start()
        clientB_.start()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            self.clientB_.publish(channel: 1, msg: msg)
        }
        wait(for: [expectationA], timeout: 5)
    }
    
    func testSubscribeAfterStart() throws {
        let expectationA = XCTestExpectation(description: "client A receives message from B")
        
        let msg_array = Array<UInt8>(repeating: 0xef, count: 2)
        let msg = base_msg.UInt8Array(data: msg_array)
        
        clientA_.start()
        clientB_.start()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            self.clientA_.subscribe(channel: 0x01, callback: { (msg: base_msg.UInt8Array) in
                if msg.size != 2 {
                    XCTAssertFalse(true)
                }
                expectationA.fulfill()
            })
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            self.clientB_.publish(channel: 1, msg: msg)
        }
        wait(for: [expectationA], timeout: 8)
    }

    func testLargeMessages() throws {
        let expectationA = XCTestExpectation(description: "client A receives message from B")
        
        let msg_array = Array<UInt8>(repeating: 0xef, count: self.largeMessageSize)
        let msg = base_msg.UInt8Array(data: msg_array)
        
        clientA_.subscribe(channel: 0x01, callback: { (msg: base_msg.UInt8Array) in
            if msg.size != self.largeMessageSize {
                XCTAssertFalse(true)
            }
            expectationA.fulfill()
        })
        
        clientA_.start()
        clientB_.start()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 4) {
            self.clientB_.publish(channel: 1, msg: msg)
        }
        wait(for: [expectationA], timeout: 5)
    }

    func testPerformanceLargeMessages() {
        clientA_.start()
        clientB_.start()
        
        let msg_array = Array<UInt8>(repeating: 0xef, count: self.largeMessageSize)
        let msg = base_msg.UInt8Array(data: msg_array)
        
        self.measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
                let expectation = XCTestExpectation(description: "client A receives message from B")
                
                self.clientA_.subscribe(channel: 0x01, callback: { (msg: base_msg.UInt8Array) in
                    expectation.fulfill()
                })
                
                DispatchQueue.global().asyncAfter(deadline: .now() + 4) {
                    self.startMeasuring()
                    self.clientB_.publish(channel: 0x01, msg: msg)
                }
                
                self.wait(for: [expectation], timeout: 5)
                self.stopMeasuring()
        }
    }

}
