//
//  Exchange.swift
//  
//
//  Created by Daniel Riege on 08.05.23.
//

import Foundation
import BinaryCodable
import Network

/**
 Handles all swiftrobot protocol related things for after connected clients.
 
 It will take care of dispatching messages to other clients depending on their subscribe requests, will check if connections are timed out and will handle handshake for new connections by providing the necessary information.
 
 Via the `ClientDispatcherDelegate` the dispatching to local subscribers in the system is delgated.
 
- note: new protocol features should be implemented here.
 */
class ClientDispatcher {
    public var delegate: ClientDispatcherDelegate?
    
    private let keepAliveTimeout: Double = 2.0 // seconds
    private let keepAliveWaitingTime: Double = 1.0 // seconds
    private let keepAliveCheckTimer: Double = 0.3 // seconds
    private let keepAliveCheckTimerRandomOffset: Double = 0.3 // seconds
    private var keepAliveCheckRunning = false
    
    private let globalServiceName: String
    private let llserver: LLServer
    private let bonjourBrowser: BonjourBrowser
    private let serialClientQueue: DispatchQueue
    
    private var clients: [String: ExternalClient]
    private var clientChannelSubcriptions: Set<UInt16>
    
    init(globalServiceName: String, port: UInt16? = nil, queue: DispatchQueue) {
        self.globalServiceName = globalServiceName
        self.llserver = LLServer(port: port, serviceName: self.globalServiceName, queue: queue)
        self.bonjourBrowser = BonjourBrowser(queue: queue, ownServiceName: self.globalServiceName)
        self.clients = [String: ExternalClient]()
        self.clientChannelSubcriptions = Set<UInt16>()
        self.serialClientQueue = DispatchQueue(label: "clientSerialQueue")
        self.delegate = nil
    }
    
    func start() {
        // create serving part
        self.llserver.recievePacketCallback = self.multiplexIncomingPacket(clientid: type: data:)
        self.llserver.clientDisconnectedCallback = self.callbackClientDisconnected(clientid:)
        try! self.llserver.start()
        self.startKeepAliveCheckCycle()
        
        // create using part
        self.bonjourBrowser.foundEndpointCallback = callbackBonjourServiceFound(serviceName:nwendpoint:)
        self.bonjourBrowser.start()
    }
    
    func stop() {
        self.clients = [String: ExternalClient]()
        self.stopKeepAliveCheckCycle()
        self.llserver.stop()
        
        self.bonjourBrowser.stop()
    }
    
    /**
     Dispatches a message to other clients if they have subscribed to this channel
     */
    func dispatchMessage(channel: UInt16, msg: Msg) {
        self.serialClientQueue.sync {
            for client in clients.values {
                if client.subscriptions.contains(channel) {
                    do {
                        try self.sendMessage(clientid: client.clientID,channel: channel, msg: msg)
                    } catch {
                        
                    }
                }
            }
        }
    }
    
    /**
     Sends a subscribe request to all other clients to let them know we want to get messages on this channel.
     */
    func subscribeRequest(channel: UInt16) {
        // this might no send anything at all when there are no connections yet
        self.clientChannelSubcriptions.insert(channel)
        self.sendSubscribeRequests(channel: channel)
    }
    
    /**
     Checks every `keepAliveCheckTimer` if the last incoming message is too old. If so, it will send out a keep alive request. If no anwser arrives, the client connection will be closed.
     
     - note: will call itself repeatedly, so only call once.
     */
    private func startKeepAliveCheckCycle() {
        keepAliveCheckRunning = true
        
        let randomOffset = Double.random(in: 0...keepAliveCheckTimerRandomOffset)
        DispatchQueue.global().asyncAfter(deadline: .now() + keepAliveCheckTimer + randomOffset) {
            if !self.keepAliveCheckRunning {
                return
            }
            self.serialClientQueue.sync {
                for clientid in self.clients.keys {
                    if self.isTimedOut(clientid: clientid) {
                        self.sendKeepAlive(clientid: clientid)
                        DispatchQueue.global().asyncAfter(deadline: .now() + self.keepAliveWaitingTime) {
                            if !self.keepAliveCheckRunning {
                                return
                            }
                            if self.isTimedOut(clientid: clientid) {
                                print("\(self.globalServiceName): \(clientid) timed out")
                                self.llserver.disconnectToDevice(clientID: clientid)
                                // removal from dict is done automatically after successfull disconnect
                            }
                        }
                    }
                }
            }
            if self.llserver.state == .ready {
                self.startKeepAliveCheckCycle()
            }
        }
    }
    
    private func stopKeepAliveCheckCycle() {
        self.keepAliveCheckRunning = false
    }
    
    private func updateKeepAliveTime(clientid: String) {
        self.serialClientQueue.sync {
            if clients[clientid] != nil {
                clients[clientid]!.lastKeepAliveResponse = .now()
            }
        }
    }
    
    private func isTimedOut(clientid: String) -> Bool {
        // no sync since only called inside a queue job
        if let client = self.clients[clientid] {
            if client.lastKeepAliveResponse + keepAliveTimeout < .now() {
                return true
            }
        }
        return false
    }
    
    // MARK: - Callbacks
    
    private func callbackClientDisconnected(clientid: String) {
        self.serialClientQueue.sync {
            _ = clients.removeValue(forKey: clientid)
        }
        let statusUpdateMsg = internal_msgs.UpdateMsg(clientID: clientid, status: .disconnected)
        delegate?.didReceiveMessage(msg: statusUpdateMsg, channel: 0)
    }
    
    private func callbackBonjourServiceFound(serviceName: String, nwendpoint: NWEndpoint) {
        self.llserver.connect(to: nwendpoint, clientID: serviceName) {
            self.sendConnect(clientid: serviceName)
        }
    }
    
    // MARK: - Protocol Implementation: Handler
    
    private func multiplexIncomingPacket(clientid: String, type: swiftrobot_packet_type, data: Data) {
        switch type {
        case .USBMuxPacketTypeResult: break
        case .USBMuxPacketTypeConnect: break
        case .USBMuxPacketTypeListen: break
        case .USBMuxPacketTypeDeviceAdd: break
        case .USBMuxPacketTypeDeviceRemove: break
        case .USBMuxPacketTypePlistPayload: break
        case .SwiftRobotPacketTypeMessage:
            self.handleMessage(clientid: clientid, data: data)
        case .SwiftRobotPacketTypeSubscribeRequest:
            self.handleSubscribeRequest(clientid: clientid, data: data)
        case .SwiftRobotPacketTypeKeepAliveRequest:
            self.handleKeepAliveRequest(clientid: clientid)
        case .SwiftRobotPacketTypeKeepAliveResponse:
            self.handleKeepAliveResponse(clientid: clientid)
        case .SwiftRobotPacketTypeConnect:
            self.handleConnect(clientid: clientid, data: data)
        case .SwiftRobotPacketTypeConnectAck:
            self.handleConnectAck(clientid: clientid, data: data)
        }
    }
    
    private func handleMessage(clientid: String, data: Data) {
        updateKeepAliveTime(clientid: clientid)
        // deserialize message
        do {
            let packet = try BinaryDataDecoder().decode(MessagePacket.self, from: data)
            if let msgType: Msg.Type = MessagePacket.type_lookup_table[packet.type] {
                let msg = try BinaryDataDecoder().decode(msgType, from: packet.data)
                delegate?.didReceiveMessage(msg: msg, channel: packet.channel)
            }
        } catch(let error) {
            print("Unexpected error: \(error.localizedDescription).")
        }
    }
    
    private func handleConnect(clientid: String, data: Data) {
        handleConnectAck(clientid: clientid, data: data)
        self.sendConnectAck(clientid: clientid)
    }
    
    private func handleConnectAck(clientid: String, data: Data) {
        var new_client = ExternalClient(clientID: clientid, lastKeepAliveResponse: .now())
        
        do {
            let connect_packet = try BinaryDataDecoder().decode(swiftrobot_packet_connect.self, from: data)
            new_client.subscriptions = connect_packet.channels
        } catch {}
        
        self.serialClientQueue.sync {
            clients[clientid] = new_client
        }
        let statusUpdateMsg = internal_msgs.UpdateMsg(clientID: clientid, status: .connected)
        delegate?.didReceiveMessage(msg: statusUpdateMsg, channel: 0)
    }
    
    private func handleSubscribeRequest(clientid: String, data: Data) {
        // for subscribe request we dont need a packet since its only a UInt16
        data.withUnsafeBytes { buffer in
            let channelToSubscribe = buffer.load(as: UInt16.self)
            self.serialClientQueue.sync {
                if self.clients[clientid] != nil {
                    self.clients[clientid]!.subscriptions.append(channelToSubscribe)
                }
            }
        }
    }
    
    private func handleKeepAliveRequest(clientid: String) {
        updateKeepAliveTime(clientid: clientid)
        sendKeepAliveResponse(clientid: clientid)
    }
    
    private func handleKeepAliveResponse(clientid: String) {
        updateKeepAliveTime(clientid: clientid)
    }
    
    // MARK: - Protocol Implementation: Sending
    
    private func sendMessage(clientid: String, channel: UInt16, msg: Msg) throws {
        // serialize message
        let payload: Data = try BinaryDataEncoder().encode(msg)
        let packet = MessagePacket(channel: channel, type: msg.getType(), data_size: UInt32(payload.count), data: payload)
        let packet_data: Data = try BinaryDataEncoder().encode(packet)
        
        // send message
        self.llserver.sendPacket(to: clientid, data: packet_data, type: .SwiftRobotPacketTypeMessage)
    }
    
    private func sendSubscribeRequests(channel: UInt16) {
        var channel_mut = channel
        let channel_data = Data(bytes: &channel_mut, count: MemoryLayout<UInt16>.size)
        self.llserver.sendPacketToAll(channel_data, type: .SwiftRobotPacketTypeSubscribeRequest)
    }
    
    private func sendConnect(clientid: String, ack: Bool = false) {
        do {
            let channels_to_subscribe = Array(clientChannelSubcriptions)
            let connect_msg = swiftrobot_packet_connect(name: self.globalServiceName, channels_to_subscribe: channels_to_subscribe)
            let connect_data: Data = try BinaryDataEncoder().encode(connect_msg)
            if ack {
                self.llserver.sendPacket(to: clientid, data: connect_data, type: .SwiftRobotPacketTypeConnectAck)
            } else {
                self.llserver.sendPacket(to: clientid, data: connect_data, type: .SwiftRobotPacketTypeConnect)
            }
        } catch {}
    }
    
    private func sendConnectAck(clientid: String) {
        sendConnect(clientid: clientid, ack: true)
    }
    
    private func sendKeepAlive(clientid: String, ack: Bool = false) {
        if ack {
            self.llserver.sendPacket(to: clientid, data: Data(), type: .SwiftRobotPacketTypeKeepAliveResponse)
        } else {
            self.llserver.sendPacket(to: clientid, data: Data(), type: .SwiftRobotPacketTypeKeepAliveRequest)
        }
    }
    
    private func sendKeepAliveResponse(clientid: String) {
        sendKeepAlive(clientid: clientid, ack: true)
    }
}
