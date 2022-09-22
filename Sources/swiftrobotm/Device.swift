import Foundation
import Network
import BinaryCodable

class Device {
    //The TCP maximum package size is 64K 65536
    let MTU = 65536

    private static var nextID: Int = 0
    let connection: NWConnection
    let id: Int
    var buffer: Data?
    var bufferLength: UInt32?

    init(nwConnection: NWConnection) {
        connection = nwConnection
        id = Device.nextID
        Device.nextID += 1
    }

    var didStopCallback: (() -> Void)? = nil
    var didReceivePacket: ((UInt8, swiftrobot_packet_type, Data) -> Void)? = nil

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
                        let usbmux_packet = try BinaryDataDecoder().decode(swiftrobot_packet.self, from: self.buffer!)
                        // erase buffer
                        self.handlePacket(packet: usbmux_packet)
                    } catch {
                        print("Error unpacking usbmux_packet")
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
                        let usbmux_packet = try BinaryDataDecoder().decode(swiftrobot_packet.self, from: self.buffer!.subdata(in: 0..<Int(self.bufferLength!)))
                        self.handlePacket(packet: usbmux_packet)
                    } catch {
                        print("Error unpacking usbmux_packet")
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
    
    private func handlePacket(packet: swiftrobot_packet) {
        if let callback = self.didReceivePacket {
            callback(UInt8(self.id), packet.type, packet.payload)
        }
    }


    func send(data: Data, type: swiftrobot_packet_type) {
        // build packet
        do {
            let swiftrobot_packet = swiftrobot_packet(swiftrobot_protocol: .SwiftRobotPacketProtocol, type: type, tag: 3, payload: data)
            let swiftrobot_packet_data: Data = try BinaryDataEncoder().encode(swiftrobot_packet)
            self.connection.send(content: swiftrobot_packet_data, completion: .contentProcessed( { error in
                if let error = error {
                    self.connectionDidFail(error: error)
                    return
                }
            }))
        } catch {
            
        }
    }

    private func connectionDidFail(error: Error) {
        print("connection did fail. Probably disconnected by peer")
        informAboutStop()
    }

    public func stop() {
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
