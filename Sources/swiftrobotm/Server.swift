import Foundation
import Network
import SwiftUI

class Server {
    private static let automaticRestartDelay: Double = 10.0 // seconds
    
    private let port: NWEndpoint.Port
    private let tcpParameters: NWParameters
    private var listener: NWListener?
    private let queue: DispatchQueue
    private var devices: [Int: Device] = [:]
    
    private var recievePacketCallback: ((UInt8, swiftrobot_packet_type, Data) -> Void)?
    private var statusUpdateCallback: ((UInt8, internal_msgs.UpdateMsg.status_t) -> Void)?
    
    public var running: Bool

    init(port: UInt16, queue: DispatchQueue) {
        self.queue = queue
        self.running = false
        let tcpOptions = NWProtocolTCP.Options()
        tcpParameters = NWParameters(tls:nil, tcp:tcpOptions  )
        tcpParameters.prohibitedInterfaceTypes = [.cellular]
        //tcpParameters.requiredInterfaceType = .loopback
        self.port = NWEndpoint.Port(rawValue: port)!
        initListener()
    }
    
    deinit {
        for device in self.devices.values {
            device.stop()
        }
        guard let listener = listener else {
            return
        }
        listener.cancel()
        print("closing server")
    }
    
    private func initListener() {
        listener = try! NWListener(using: tcpParameters, on: self.port)
    }

    func startLookingForConnections() throws {
        guard let listener = listener else {
            return
        }
        listener.stateUpdateHandler = self.serverStateDidChange(to:)
        listener.newConnectionHandler = self.createClient(nwConnection:)
        listener.start(queue: self.queue)
        self.running = true
    }
    
    func sendPacket(to deviceID: Int, data: Data, type: swiftrobot_packet_type) {
        if let device = self.devices[deviceID] {
            device.send(data: data, type: type)
        }
    }
    
    func sendPacketToAll(_ data: Data, type: swiftrobot_packet_type) {
        for deviceID in self.devices.keys {
            sendPacket(to: deviceID, data: data, type: type)
        }
    }
    
    func disconnectToDevice(deviceID: Int) {
        if self.devices[deviceID] != nil {
            self.devices[deviceID]!.stop()
        }
    }

    private func serverStateDidChange(to newState: NWListener.State) {
        switch newState {
        case .failed(let error):
            if error == .posix(.EADDRINUSE) {
                print("Server port already in use... Automatic restart in \(Server.automaticRestartDelay) seconds.")
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
    private func createClient(nwConnection: NWConnection) {
        let device = Device(nwConnection: nwConnection)
        self.devices[device.id] = device
        device.didStopCallback = {
            self.connectionDidStop(device)
        }
        device.didReceivePacket = { (deviceID, type, data) in
            if self.recievePacketCallback != nil {
                self.recievePacketCallback!(deviceID, type, data)
            }
        }
        device.start()
        
        if let suCall = statusUpdateCallback {
            suCall(UInt8(device.id), .connected)
        }
    }

    private func connectionDidStop(_ connection: Device) {
        self.devices.removeValue(forKey: connection.id)
        if let suCall = statusUpdateCallback {
            suCall(UInt8(connection.id), .disconnected)
        }
    }
    
    private func restart() {
        self.stop()
        DispatchQueue.global().asyncAfter(deadline: .now() + Server.automaticRestartDelay) {
            do {
                self.initListener()
                try self.startLookingForConnections()
            } catch {
                
            }
        }
    }

    private func stop() {
        guard let listener = listener else {
            return
        }
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        for connection in self.devices.values {
            connection.didStopCallback = nil
            connection.stop()
        }
        listener.cancel()
        self.devices.removeAll()
        self.running = false
        self.listener = nil
    }
    
    // MARK: - Register callbacks
    
    func registerPacketReceivedCallback(callback: @escaping (UInt8, swiftrobot_packet_type, Data) -> Void) {
        self.recievePacketCallback = callback
    }
    
    func registerStatusUpdateCallback(callback: @escaping (UInt8, internal_msgs.UpdateMsg.status_t) -> Void) {
        self.statusUpdateCallback = callback
    }
}
