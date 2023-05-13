import Foundation
import Network
import SwiftUI

public typealias LLServerState = NWListener.State

/**
Low level server which handles the `LLConnections`.  It looks for incoming connections or can be used to connect to a different `LLServer` instance.
 To be found, it advertises its listener as a bonjour service on `.local` domain with `_swiftrobot._tcp` type.
 */
class LLServer {
    private static let automaticRestartDelay: Double = 10.0 // seconds
    private static let defaultPort: uint16 = 4455
    private let maxConnectDelay: Double = 2 // s
    
    private var explicitPort: Bool
    private var port: NWEndpoint.Port
    private let tcpParameters: NWParameters
    private let serviceName: String
    private var listener: NWListener?
    private let queue: DispatchQueue
    private var connections: [LLConnection] = [LLConnection]()
    
    /// current state of the server
    var state: LLServerState

    /**
      - parameters:
        - port: listening port. If nil, some free port will be used.
        - serviceName: Name of this server. Will be used as bonjour service name.
        - queue: queue for message handling
     */
    init(port: UInt16? = nil, serviceName: String, queue: DispatchQueue) {
        self.queue = queue
        self.serviceName = serviceName
        self.state = .setup
        let tcpOptions = NWProtocolTCP.Options()
        tcpParameters = NWParameters(tls:nil, tcp:tcpOptions  )
        tcpParameters.prohibitedInterfaceTypes = [.cellular]
        tcpParameters.allowLocalEndpointReuse = true
        //tcpParameters.requiredInterfaceType = .loopback
        self.explicitPort = (port != nil)
        self.port = NWEndpoint.Port(rawValue: port ?? LLServer.defaultPort)!
    }
    
    deinit {
        for device in self.connections {
            device.stop()
        }
        guard let listener = listener else {
            return
        }
        listener.cancel()
        print("closing server")
    }
    
    /**
        Set this to be notified when some` LLConnection` receives a new packet
     */
    var recievePacketCallback: ((String, swiftrobot_packet_type, Data) -> Void)?
    
    /**
     Set this to be notified when some `LLConnection` is disconnected
     */
    var clientDisconnectedCallback: ((String) -> Void)?

    /**
     Starts listening on either the specified port or the dynamic chosen port. Will also advertise the service with bonjour.
     */
    func start() throws {
        listener = try! NWListener(using: tcpParameters, on: self.port)
        listener!.stateUpdateHandler = self.serverStateDidChange(to:)
        listener!.newConnectionHandler = self.callbackNewConnection(nwConnection:)
        // advertise bonjour service
        listener!.service = NWListener.Service(name: serviceName, type: "_swiftrobot._tcp", domain: "local")
        listener!.start(queue: self.queue)
    }
    
    /**
     Stops listening and disconnects to all services.
     */
    func stop() {
        guard let listener = listener else {
            return
        }
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        for connection in self.connections {
            connection.didStopCallback = nil
            connection.stop()
        }
        if listener.state == .ready {
            listener.cancel()
        }
        self.connections.removeAll()
        self.listener = nil
    }
    
    /**
     Sends data to a connection as a swiftrobot_packet
     
     - parameters:
        - clientID: clientID of the connection which should receive this packet
        - data: data which will be sent
        - type: package type as which the created package will be sent
     */
    func sendPacket(to clientID: String, data: Data, type: swiftrobot_packet_type) {
        if let client = getConnectionForClientID(clientID: clientID) {
            client.send(data: data, type: type)
        }
    }
    
    /**
     Sends data to all connections as a swiftrobot_packet
     
     - parameters:
        - data: data which will be sent
        - type: package type as which the created package will be sent
     */
    func sendPacketToAll(_ data: Data, type: swiftrobot_packet_type) {
        for client in self.connections {
            client.send(data: data, type: type)
        }
    }
    
    /**
     Create a new connection after a random deadline to minimize risk of double connection (If both ends make a connection at the same time)
     
     - parameters:
        - endpoint: Endpoint of the new connection
        - clientID: clientID of the new connection (Should come from a bonjour browser)
        - connectRequestSent: callback which is called when the connection request was sent
     */
    func connect(to endpoint: NWEndpoint, clientID: String, connectRequestSent: @escaping (() -> Void)) {
        let delayTime = Double.random(in: 0...maxConnectDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) {
            if self.getConnectionForClientID(clientID: clientID) == nil {
                let conn = LLConnection(name: clientID, endpoint: endpoint)
                self.addConnection(conn: conn)
                connectRequestSent()
            }
        }
    }
    
    /**
     Disconnects a connection
     - parameter clientID: clientID of the connection which shall be disconnected
     */
    func disconnectToDevice(clientID: String) {
        if let client = getConnectionForClientID(clientID: clientID) {
            client.stop()
        }
    }
    
    private func getConnectionForClientID(clientID: String) -> LLConnection? {
        for conn in self.connections {
            if conn.name == clientID {
                return conn
            }
        }
        return nil
    }
    
    private func serverStateDidChange(to newState: NWListener.State) {
        self.state = newState
        switch newState {
        case .failed(let error):
            if error == .posix(.EADDRINUSE) {
                self.restart()
            } else {
                print("Server starting failed with: \(error.debugDescription)")
                self.stop()
            }
        default:
            break
        }
    }

    /// This function is called when a new connection is being established
    private func callbackNewConnection(nwConnection: NWConnection) {
        let conn = LLConnection(nwConnection: nwConnection)
        self.addConnection(conn: conn)
    }
    
    private func addConnection(conn: LLConnection) {
        self.connections.append(conn)
        conn.didStopCallback = {
            self.connectionDidStop(conn)
        }
        conn.didReceivePacket = { (connID, type, data) in
            if self.recievePacketCallback != nil {
                self.recievePacketCallback!(connID, type, data)
            }
        }
        conn.start()
    }

    private func connectionDidStop(_ connection: LLConnection) {
        self.connections.removeAll { conn in
            return conn.localID == connection.localID
        }
        if let name = connection.name, let callback = clientDisconnectedCallback {
            callback(name)
        }
    }
    
    private func restart() {
        self.stop()
        if explicitPort {
            print("Server port already in use... Automatic restart in \(LLServer.automaticRestartDelay) seconds.")
            DispatchQueue.global().asyncAfter(deadline: .now() + LLServer.automaticRestartDelay) {
                do {
                    try self.start()
                } catch {
                    
                }
            }
        } else {
            self.port = NWEndpoint.Port(rawValue: self.port.rawValue + 1)!
            print("Server port already in use... Trying now \(self.port) as port")
            do {
                try self.start()
            } catch {}
        }
    }
    
}
