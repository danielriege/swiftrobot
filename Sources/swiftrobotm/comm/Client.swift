import Foundation
import Network
import BinaryCodable

struct usbmux_packet: BinaryCodable {
    
    enum usbmux_protocol_t: UInt32, BinaryCodable {
        case USBMuxPacketProtocolBinary = 0
        case USBMuxPacketProtocolPlist = 1
    }
    
    enum usbmux_type_t: UInt32, BinaryCodable {
        case USBMuxPacketTypeResult = 1
        case USBMuxPacketTypeConnect = 2
        case USBMuxPacketTypeListen = 3
        case USBMuxPacketTypeDeviceAdd = 4
        case USBMuxPacketTypeDeviceRemove = 5
        // ? = 6,
        // ? = 7,
        case USBMuxPacketTypePlistPayload = 8 // only supported type by usbmuxd by now
        // Custom Types
        case USBMuxPacketTypeApplicationData = 9
    }
    
    let length: UInt32
    let usbmux_protocol: usbmux_protocol_t
    let type: usbmux_type_t
    let tag: UInt32
    let payload: Data
    
    init(usbmux_protocol: usbmux_protocol_t, type: usbmux_type_t, tag: UInt32, payload: Data) {
        self.length = UInt32(16 + payload.count)
        self.usbmux_protocol = usbmux_protocol
        self.type = type
        self.tag = tag
        self.payload = payload
    }
    
    init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        self.length = try container.decode(UInt32.self)
        
        var protocolContainer = container.nestedContainer(maxLength: 4) // uint32_t is 4 bytes
        self.usbmux_protocol = try protocolContainer.decode(usbmux_protocol_t.self)
        
        var typeContainer = container.nestedContainer(maxLength: 4) // uint32_t is 4 bytes
        self.type = try typeContainer.decode(usbmux_type_t.self)
        
        self.tag = try container.decode(UInt32.self)
        self.payload = try container.decode(length: Int(self.length - 16)) // previous types are 16 bytes in total
    }
    
    func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        try container.encode(length)
        try container.encode(usbmux_protocol)
        try container.encode(type)
        try container.encode(tag)
        try container.encode(sequence: payload)
    }
}

class Client {
    //The TCP maximum package size is 64K 65536
    let MTU = 65536

    private static var nextID: Int = 0
    let connection: NWConnection
    let id: Int
    var buffer: Data?
    var bufferLength: UInt32?

    init(nwConnection: NWConnection) {
        connection = nwConnection
        id = Client.nextID
        Client.nextID += 1
    }

    var didStopCallback: ((Error?) -> Void)? = nil
    var didReceiveMessage: ((Data) -> Void)? = nil

    func start() {
        connection.stateUpdateHandler = self.stateDidChange(to:)
        setupReceive()
        connection.start(queue: .main)
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            break
        case .failed(let error):
            connectionDidFail(error: error)
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
//                    let numberOfRecieves = Int(ceil(Double(messageSize)/Double(self.MTU)))
//                    self.bufferSegmentsAwaiting = numberOfRecieves - 1 // minus 1 because we already received one
                    // load received data into buffer
                    self.buffer = data
                } else {
                    // we append the data
                    self.buffer!.append(data)
//                    self.bufferSegmentsAwaiting! = self.bufferSegmentsAwaiting! - 1
                }
                if self.buffer!.count == self.bufferLength! {
                    // unpack usbmux packet
                    do {
                        let usbmux_packet = try BinaryDataDecoder().decode(usbmux_packet.self, from: self.buffer!)
                        // erase buffer
                        if let callback = self.didReceiveMessage {
                            callback(usbmux_packet.payload)
                        }
                    } catch {
                        print("Error unpacking usbmux_packet")
                    }
                    self.buffer = nil
                    self.bufferLength = nil
                } else if self.buffer!.count > self.bufferLength! {
                    // siomething went terribly wrong
                    print("Major problem receiving stream! We received more data than expected!")
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


    func send(data: Data) {
        // build usbmux packet
        do {
            let usbmux_packet = usbmux_packet(usbmux_protocol: .USBMuxPacketProtocolBinary, type: .USBMuxPacketTypeApplicationData, tag: 3, payload: data)
            let usbmux_packet_data: Data = try BinaryDataEncoder().encode(usbmux_packet)
            self.connection.send(content: usbmux_packet_data, completion: .contentProcessed( { error in
                if let error = error {
                    self.connectionDidFail(error: error)
                    return
                }
            }))
        } catch {
            
        }
    }

    func stop() {
        print("connection \(id) will stop")
    }



    private func connectionDidFail(error: Error) {
        print("connection \(id) did fail, error: \(error)")
        stop(error: error)
    }

    private func connectionDidEnd() {
        print("connection \(id) did end")
        stop(error: nil)
    }

    private func stop(error: Error?) {
        connection.stateUpdateHandler = nil
        connection.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
}
