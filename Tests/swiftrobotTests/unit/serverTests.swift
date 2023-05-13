//
//  serverTests.swift
//  
//
//  Created by Daniel Riege on 11.05.23.
//

import XCTest
import Network
@testable import swiftrobot

final class serverTests: XCTestCase {
    
    private let queue = DispatchQueue(label: "server test queue")

    func testRestart() throws {
        let waitTime = expectation(description: "waiting")
        let waitTime2 = expectation(description: "waiting")
        let waitTime3 = expectation(description: "waiting")
        waitTime.isInverted = true
        waitTime2.isInverted = true
        waitTime3.isInverted = true
        
        var server = LLServer(port: 9012, serviceName: "client", queue: queue)
        try server.start()
        
        wait(for: [waitTime], timeout: 0.2)
        XCTAssertTrue(server.state == .ready)
        server.stop()
        server = LLServer(port: 9012, serviceName: "client", queue: queue)
        wait(for: [waitTime2], timeout: 0.2)
        XCTAssertFalse(server.state == .cancelled)
        try server.start()
        wait(for: [waitTime3], timeout: 0.2)
        XCTAssertTrue(server.state == .ready)
    }
    
    func testRestartWithConnection() throws {
        let waitTime = expectation(description: "waiting")
        let waitTime2 = expectation(description: "waiting")
        let waitTime3 = expectation(description: "waiting")
        let waitTime4 = expectation(description: "waiting")
        waitTime.isInverted = true
        waitTime2.isInverted = true
        waitTime3.isInverted = true
        waitTime4.isInverted = true
        
        var server = LLServer(port: 9011, serviceName: "client", queue: queue)
        try server.start()
        wait(for: [waitTime], timeout: 0.2)
        
        let host: NWEndpoint.Host = "127.0.0.1"
        let port: NWEndpoint.Port = 9011
        let connection = LLConnection(nwConnection: NWConnection(host: host, port: port, using: .tcp))
        connection.start()
        wait(for: [waitTime4], timeout: 0.5)
        
        XCTAssertTrue(connection.connection.state == .ready)
        XCTAssertTrue(server.state == .ready)
        server.stop()
        server = LLServer(port: 9011, serviceName: "client", queue: queue)
        wait(for: [waitTime2], timeout: 0.2)
        XCTAssertFalse(server.state == .cancelled)
        try server.start()
        wait(for: [waitTime3], timeout: 0.2)
        XCTAssertTrue(server.state == .ready)
    }

}
