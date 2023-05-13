//
//  File.swift
//  
//
//  Created by Daniel Riege on 05.05.23.
//

import Foundation

/**
Representation of an externally connected swiftrobot client
 */
struct ExternalClient {
    let clientID: String
    var lastKeepAliveResponse: DispatchTime
    var subscriptions = [UInt16]()
}
