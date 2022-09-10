import Foundation
import Network
import SwiftUI

class Hub {
    let port: NWEndpoint.Port
    let listener: NWListener

    private var clients: [Int: Client] = [:]
    private var recieveCallback: ((Data) -> Void)?
    private var statusUpdateCallback: ((UInt8, internal_msgs.UpdateMsg.status_t) -> Void)?

    init(port: UInt16) {
        let tcpOptions = NWProtocolTCP.Options()
        let tcpParameters = NWParameters(tls:nil, tcp:tcpOptions  )
        tcpParameters.prohibitedInterfaceTypes = [.cellular]
        //tcpParameters.requiredInterfaceType = .loopback
        self.port = NWEndpoint.Port(rawValue: port)!
        listener = try! NWListener(using: tcpParameters, on: self.port)
    }
    
    deinit {
        for client_ in self.clients.values {
            client_.stop()
        }
        listener.cancel()
        print("closing server")
    }

    func startLookingForConnections() throws {
        listener.stateUpdateHandler = self.stateDidChange(to:)
        listener.newConnectionHandler = self.createClient(nwConnection:)
        listener.start(queue: .main)
    }
    
    func sendPacket(to clientID: Int, data: Data) {
        if let client = self.clients[clientID] {
            client.send(data: data)
        }
    }
    
    func sendPacketToAll(_ data: Data) {
        for clientID in self.clients.keys {
            sendPacket(to: clientID, data: data)
        }
    }
    
    func registerRecieveCallback(callback: @escaping (Data) -> Void) {
        self.recieveCallback = callback
    }
    
    func registerStatusUpdateCallback(callback: @escaping (UInt8, internal_msgs.UpdateMsg.status_t) -> Void) {
        self.statusUpdateCallback = callback
    }

    private func stateDidChange(to newState: NWListener.State) {
        switch newState {
        case .ready:
          break
        case .failed(let error):
            print("Server failure, error: \(error.localizedDescription)")
            exit(EXIT_FAILURE)
        default:
            break
        }
    }

    private func createClient(nwConnection: NWConnection) {
        let client = Client(nwConnection: nwConnection)
        self.clients[client.id] = client
        client.didStopCallback = {
            self.connectionDidStop(client)
        }
        client.didReceiveMessage = { data in
            if self.recieveCallback != nil {
                self.recieveCallback!(data)
            }
        }
        client.start()
        
        if let suCall = statusUpdateCallback {
            suCall(UInt8(client.id), .connected)
        }
    }

    private func connectionDidStop(_ connection: Client) {
        self.clients.removeValue(forKey: connection.id)
        if let suCall = statusUpdateCallback {
            suCall(UInt8(connection.id), .disconnected)
        }
    }

    private func stop() {
        self.listener.stateUpdateHandler = nil
        self.listener.newConnectionHandler = nil
        self.listener.cancel()
        for connection in self.clients.values {
            connection.didStopCallback = nil
            connection.stop()
        }
        self.clients.removeAll()
    }
}
