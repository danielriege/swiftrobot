//
//  Subscriber.swift
//  
//
//  Created by Daniel Riege on 05.05.23.
//

import Foundation

/**
 Representation of a Subscriber on the local system
 */
class Subscriber {
    private static var nextID = 0
    let id: Int
    let callback: Any
    let priority: SubscriberPriority
    let queue_size: Int
    let semaphore: DispatchSemaphore
    
    init(callback: Any, priority: SubscriberPriority, queue_size: Int) {
        self.callback = callback
        self.priority = priority
        self.queue_size = queue_size
        self.semaphore = DispatchSemaphore(value: queue_size)
        self.id = Subscriber.nextID
        Subscriber.nextID += 1
    }
}
