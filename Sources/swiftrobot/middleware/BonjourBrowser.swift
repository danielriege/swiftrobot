//
//  File.swift
//  
//
//  Created by Daniel Riege on 05.05.23.
//

import Foundation
import Network

/**
 Browser for swiftrobot cleints using bonjour.
 
 Will search for swiftrobot clients on the local network.
 - note: After results were found, the browser will close automatically (to prevent double connections)
 */
class BonjourBrowser {
    private var browser: NWBrowser?
    private let ownServiceName: String
    private let queue: DispatchQueue
    
    private var discoveries: Set<NWEndpoint>
    
    /**
     callback which will be called after clients were found. First parameter is the clientID and second parameter is the endpoint of the newly found client.
     */
    var foundEndpointCallback: ((String, NWEndpoint) -> Void)?
    
    init(queue: DispatchQueue, ownServiceName: String) {
        self.queue = queue
        self.ownServiceName = ownServiceName
        self.discoveries = Set<NWEndpoint>()
    }
    
    /**
     Start looking for clients on local network.
     */
    func start() {
        browser = NWBrowser(for: .bonjour(type: "_swiftrobot._tcp", domain: "local"), using: .tcp)
        browser!.stateUpdateHandler = browserStateChanged(state:)
        browser!.browseResultsChangedHandler = browserResultsChanged(results:changes:)
        browser!.start(queue: queue)
    }
    
    /**
     Close the search browser.
     
     - note: browser will close automatically after the first services were found (prevents double connections)
     */
    func stop() {
        if let browser = self.browser {
            browser.cancel()
            self.discoveries.removeAll()
            self.browser = nil
        }
    }
    
    func getDiscoveries() -> Set<NWEndpoint> {
        return discoveries
    }
    
    private func browserResultsChanged(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for result in results {
            // do not connect to own service
            if case .service(let name, _, _, _) = result.endpoint {
                if name != ownServiceName {
                    let insert = discoveries.insert(result.endpoint)
                    if insert.inserted {
                        if let callback = foundEndpointCallback {
                            callback(name, result.endpoint)
                        }
                    }
                }
            }
        }
        if let browser = self.browser {
            browser.cancel()
        }
    }
    
    private func browserStateChanged(state: NWBrowser.State) {
        switch state {
        case .failed(let error):
            fatalError(error.localizedDescription)
        case .setup:
            break
        case .ready:
            break
        case .cancelled:
            break
        case .waiting(_):
            break
        @unknown default:
            break
        }
    }
}

