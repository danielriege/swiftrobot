//
//  externalCommTests.swift
//  
//
//  Created by Daniel Riege on 05.05.23.
//

import XCTest
@testable import swiftrobot

final class clientConnectionTests: XCTestCase {

    /// 2 clients starting up at the same time connecting each other using bonjour
    func testConnectionBuildUp2() throws {
        let clientA_ = SwiftRobotClient(name: "clientA")
        let clientB_ = SwiftRobotClient(name: "clientB")
        
        let expectationA = XCTestExpectation(description: "client A connected to B")
        let expectationAn = XCTestExpectation(description: "client A other update")
        expectationAn.isInverted = true
        let expectationB = XCTestExpectation(description: "client B connected to A")
        let expectationBn = XCTestExpectation(description: "client B other update")
        expectationBn.isInverted = true
        clientA_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
            if msg.status == .connected && msg.clientID == "clientB" {
                expectationA.fulfill()
            } else {
                print("clientA: \(msg)")
                expectationAn.fulfill()
            }
        }
        clientB_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
            if msg.status == .connected && msg.clientID == "clientA" {
                expectationB.fulfill()
            } else {
                print("clientB: \(msg)")
                expectationBn.fulfill()
            }
        }
        
        clientA_.start()
        clientB_.start()
        
        wait(for: [expectationA, expectationB, expectationAn, expectationBn], timeout: 3)
        
        clientA_.stop()
        clientB_.stop()
    }
    
    /// 2 clients starting up at the same time connecting each other using bonjour
    func testConnectionBuildUp3() throws {
        let clientA_ = SwiftRobotClient(name: "clientA")
        let clientB_ = SwiftRobotClient(name: "clientB")
        let clientC_ = SwiftRobotClient(name: "clientC")
        
        let expectationAB = XCTestExpectation(description: "client A connected to B")
        let expectationAC = XCTestExpectation(description: "client A connected to C")
        let expectationAn = XCTestExpectation(description: "client A other update")
        expectationAn.isInverted = true
        let expectationBA = XCTestExpectation(description: "client B connected to A")
        let expectationBC = XCTestExpectation(description: "client B connected to C")
        let expectationBn = XCTestExpectation(description: "client B other update")
        expectationBn.isInverted = true
        let expectationCA = XCTestExpectation(description: "client C connected to A")
        let expectationCB = XCTestExpectation(description: "client C connected to B")
        let expectationCn = XCTestExpectation(description: "client C other update")
        expectationCn.isInverted = true
        
        clientA_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
            if msg.status == .connected && msg.clientID == "clientB" {
                expectationAB.fulfill()
            } else if msg.status == .connected && msg.clientID == "clientC" {
                expectationAC.fulfill()
            } else {
                print("clientA: \(msg)")
                expectationAn.fulfill()
            }
        }
        clientB_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
            if msg.status == .connected && msg.clientID == "clientA" {
                expectationBA.fulfill()
            } else if msg.status == .connected && msg.clientID == "clientC" {
                expectationBC.fulfill()
            } else {
                print("clientB: \(msg)")
                expectationBn.fulfill()
            }
        }
        clientC_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
            if msg.status == .connected && msg.clientID == "clientA" {
                expectationCA.fulfill()
            } else if msg.status == .connected && msg.clientID == "clientB" {
                expectationCB.fulfill()
            } else {
                print("clientC: \(msg)")
                expectationCn.fulfill()
            }
        }
        
        clientA_.start()
        clientB_.start()
        clientC_.start()
        
        wait(for: [expectationAB, expectationAC, expectationAn,
                   expectationBA, expectationBC, expectationBn,
                   expectationCA, expectationCB, expectationCn,], timeout: 5)
        
        clientA_.stop()
        clientB_.stop()
        clientC_.stop()
    }
    
    /// 2 clients already running and a third client joining
    func testConnectionOneJoining() throws {
        let clientA_ = SwiftRobotClient(name: "clientA")
        let clientB_ = SwiftRobotClient(name: "clientB")
        let clientC_ = SwiftRobotClient(name: "clientC")
        
        clientA_.start()
        clientB_.start()
        let expectationCA = XCTestExpectation(description: "client C connected to A")
        let expectationCB = XCTestExpectation(description: "client C connected to B")
        let expectationAC = XCTestExpectation(description: "client A connected to C")
        let expectationBC = XCTestExpectation(description: "client B connected to C")
        let expectationAn = XCTestExpectation(description: "client A other")
        expectationAn.isInverted = true
        let expectationBn = XCTestExpectation(description: "client B other")
        expectationBn.isInverted = true
        let expectationCn = XCTestExpectation(description: "client C other")
        expectationCn.isInverted = true
        
        clientA_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
            if msg.status == .connected && msg.clientID == "clientC" {
                expectationAC.fulfill()
            } else if msg.clientID != "clientB" {
                print("clientA: \(msg)")
                expectationAn.fulfill()
            }
        }
        clientB_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
            if msg.status == .connected && msg.clientID == "clientC" {
                expectationBC.fulfill()
            } else if msg.clientID != "clientA"{
                print("clientB: \(msg)")
                expectationBn.fulfill()
            }
        }
        clientC_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
            if msg.status == .connected {
                if msg.clientID == "clientA" {
                    expectationCA.fulfill()
                } else if msg.clientID == "clientB" {
                    expectationCB.fulfill()
                } else {
                    print("clientC: \(msg)")
                    expectationCn.fulfill()
                }
            } else {
                print("clientC: \(msg)")
                expectationCn.fulfill()
            }
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 4) {
            clientC_.start()
        }
        
        wait(for: [expectationAC, expectationBC, expectationCA, expectationCB, expectationAn, expectationBn, expectationCn], timeout: 7)
        
        clientA_.stop()
        clientB_.stop()
        clientC_.stop()
    }

    /// 3 clients already connected and one client dies and then reconnects
    func testConnectionOneReconnect() throws {
        let clientA_ = SwiftRobotClient(name: "clientA")
        let clientB_ = SwiftRobotClient(name: "clientB")
        let clientC_ = SwiftRobotClient(name: "clientC")

        clientA_.start()
        clientB_.start()
        clientC_.start()

        let expectationA = XCTestExpectation(description: "client C disconnected from A")
        let expectationB = XCTestExpectation(description: "client C disconnected from B")
        let expectationCA = XCTestExpectation(description: "client C reconnects to A")
        let expectationCB = XCTestExpectation(description: "client C reconnects to B")
        
        let expectationAn = XCTestExpectation(description: "client A other")
        expectationAn.isInverted = true
        let expectationBn = XCTestExpectation(description: "client B other")
        expectationBn.isInverted = true
        let expectationCn = XCTestExpectation(description: "client C other")
        expectationCn.isInverted = true

        DispatchQueue.global().asyncAfter(deadline: .now() + 4) {

            clientA_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
                if msg.status == .disconnected && msg.clientID == "clientC" {
                    expectationA.fulfill()
                } else if msg.status == .disconnected {
                    expectationAn.fulfill()
                }
            }
            clientB_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
                if msg.status == .disconnected && msg.clientID == "clientC" {
                    expectationB.fulfill()
                } else if msg.status == .disconnected {
                    expectationBn.fulfill()
                }
            }

            // simulate program interruption
            clientC_.stop()
            print("client C program interruption simulated")

            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                // simulate program restart
                clientC_.start()
                print("client C program restart simulated")

                clientA_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
                    if msg.status == .connected && msg.clientID == "clientC" {
                        expectationCA.fulfill()
                    } else if msg.status == .connected {
                        expectationCn.fulfill()
                    }
                }
                clientB_.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
                    if msg.status == .connected && msg.clientID == "clientC" {
                        expectationCB.fulfill()
                    } else if msg.status == .connected {
                        expectationCn.fulfill()
                    }
                }
            }
        }
        self.wait(for: [expectationA, expectationB], timeout: 7)
        self.wait(for: [expectationCA, expectationCB], timeout: 10)

        clientA_.stop()
        clientB_.stop()
        clientC_.stop()
    }
}
