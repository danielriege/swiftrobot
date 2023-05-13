import Foundation
import Network
import BinaryCodable

/**
 Low level connection class which will send and receive data in the form of swiftrobot packets.
 */
class LLConnection: CustomStringConvertible {
    private static var nextID = 0
    //The TCP maximum package size is 64K 65536
    private let MTU = 65536

    let connection: NWConnection
    /// nil as long as connection did not receive welcome message
    var name: String?
    var localID: Int
    private var buffer: Data?
    private var bufferLength: UInt32?
    private var accepted = false
    
    public var description: String { return "\(name ?? "") \(accepted)" }

    init(name: String? = nil, nwConnection: NWConnection) {
        connection = nwConnection
        self.name = name
        self.localID = LLConnection.nextID
        LLConnection.nextID += 1
    }
    
    convenience init(name: String? = nil, endpoint: NWEndpoint) {
        let tcpOptions = NWProtocolTCP.Options()
        let tcpParameters = NWParameters(tls:nil, tcp:tcpOptions)
        tcpParameters.prohibitedInterfaceTypes = [.cellular]
        let conn = NWConnection(to: endpoint, using: tcpParameters)
        self.init(name: name, nwConnection: conn)
    }

    var didStopCallback: (() -> Void)? = nil
    var didReceivePacket: ((String, swiftrobot_packet_type, Data) -> Void)? = nil

    /**
     Starts the connection
     */
    func start() {
        connection.stateUpdateHandler = self.stateDidChange(to:)
        setupReceive()
        connection.start(queue: .global())
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            break
        case .failed(let error):
            connectionDidFail(error: error)
        case .cancelled:
            break
        default:
            break
        }
    }

    // recursive method
    private func setupReceive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: MTU) { (data, _, isComplete, error) in
            // message can be recieved in multiple steps
            if let data = data, !data.isEmpty {
                // if we dont already have a buffer length, it means we receive a fresh packet
                if self.bufferLength == nil && self.buffer == nil {
                    // get message size
                    let messageSize = data.withUnsafeBytes { buffer in
                        buffer.load(as: UInt32.self)
                    }
                    self.bufferLength = messageSize
                    // with message size we know how many recieves we need
                    // load received data into buffer
                    self.buffer = data
                } else {
                    // we append the data
                    self.buffer!.append(data)
                }
        
                if self.buffer!.count == self.bufferLength! {
                    // unpack usbmux packet
                    do {
                        let swiftrobot_packet = try BinaryDataDecoder().decode(swiftrobot_packet.self, from: self.buffer!)
                        // erase buffer
                        self.handlePacket(packet: swiftrobot_packet)
                    } catch {
                        print("Error unpacking swiftrobot_packet")
                    }
                    self.buffer = nil
                    self.bufferLength = nil
                } else if self.buffer!.count > self.bufferLength! {
                    // we received more data than the packet size
                    // If we have a fast stream, this could happen
                    // so we need to cut the buffer by completing
                    // a packet and simountanesly starting a new one
                    
                    // unpack usbmux packet with only bufferLength range
                    do {
                        let swiftrobot_packet = try BinaryDataDecoder().decode(swiftrobot_packet.self, from: self.buffer!.subdata(in: 0..<Int(self.bufferLength!)))
                        self.handlePacket(packet: swiftrobot_packet)
                    } catch {
                        print("Error unpacking swiftrobot_packet")
                    }
                    // use other half of the previous buffer to determine new size
                    self.buffer = self.buffer!.subdata(in: Int(self.bufferLength!)..<Int(self.buffer!.count))
                    let messageSize = self.buffer!.withUnsafeBytes { buffer in
                        buffer.load(as: UInt32.self)
                    }
                    self.bufferLength = messageSize
                }
            }
            if isComplete {
                // connection closed by peer
            } else if let error = error {
                self.connectionDidFail(error: error)
            } else {
                self.setupReceive()
            }
        }
    }
    
    /**
     Called when a whole `swiftrobot_packet` is received and distributes it further back
     
     - note: even though protocol definitions are not cared about, in case of connect packets the name of the connection will be set. This is an exception.
     */
    private func handlePacket(packet: swiftrobot_packet) {
        do {
            // exception: If packet type is connect, we need to intercept to set connection name
            if packet.type == .SwiftRobotPacketTypeConnect ||
                packet.type == .SwiftRobotPacketTypeConnectAck {
                let connect_packet = try BinaryDataDecoder().decode(swiftrobot_packet_connect.self, from: packet.payload)
                if packet.type == .SwiftRobotPacketTypeConnectAck && connect_packet.name != self.name {
                    print("something went totally wrong since we now have a connection with ourself. Trying to resolve it...")
                    self.connection.stateUpdateHandler = nil
                    self.connection.cancel()
                    return
                }
                self.name = connect_packet.name
                self.accepted = true
            }
            if let callback = self.didReceivePacket, let id = self.name {
                callback(id, packet.type, packet.payload)
            }
        } catch {}
    }

    /**
     Sends data to the represented client as a swiftrobot_packet
     
     - parameters:
        - data: data which will be sent
        - type: package type as which the created package will be sent
     */
    func send(data: Data, type: swiftrobot_packet_type) {
        // build packet
        let swiftrobot_packet = swiftrobot_packet(swiftrobot_protocol: .SwiftRobotPacketProtocol, type: type, tag: 3, payload: data)
        let swiftrobot_packet_data: Data = try! BinaryDataEncoder().encode(swiftrobot_packet)
        self.connection.send(content: swiftrobot_packet_data, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
        }))
    }

    private func connectionDidFail(error: Error) {
        informAboutStop()
    }

    /**
     Closes the connection. Will call the `didStopCallback`.
     */
    func stop() {
        connection.stateUpdateHandler = nil
        connection.cancel()
        informAboutStop()
    }
    
    private func informAboutStop() {
        if let didStopCallback = didStopCallback {
            didStopCallback()
            self.didStopCallback = nil
        }
    }
}
