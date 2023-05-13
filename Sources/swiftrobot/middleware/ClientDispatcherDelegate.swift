//
//  ClientDispatcherDelegate.swift
//  
//
//  Created by Daniel Riege on 08.05.23.
//

import Foundation

protocol ClientDispatcherDelegate {
    /**
     Called when a new message arrives and should be distributed locally
     */
    func didReceiveMessage(msg: Msg, channel: UInt16)
}
