## What is swiftrobot?

swiftrobot is a lightweight and easy-to-use middleware for robotic applications. It provides a way to communicate between different components of a robot's software stack, allowing for seamless integration and rapid development.

Using the C++ implementation [swiftrobotc](https://github.com/danielriege/swiftrobotc), it is possible to communicate with iOS devices via USB. This allows for an easy and real-time usable integration of iPhones and iPads as sensors, controllers, or displays for your robot.

With swiftrobot's publish/subscribe messaging system, you can easily build distributed systems for robots. This package includes a Swift implementation of the middleware, and it can be used to communicate between different processes on the same machine or across a local network. 

Possible use cases:

- Perception, SLAM and path planning done on iOS device, which sends out control commands via USB to robot hardware controller.
- Visualisation and debugging of robots software stack on a Wi-Fi connected iOS device
- Distributed sensor network with iOS devices

## Features

- Bonjour service discovery, so clients connect to each other without any manual configuration needed.
- Publish/Subscribe messaging system based on shared memory or TCP sockets.
- USB communication between for iOS devices using [swiftrobotc](https://github.com/danielriege/swiftrobotc).
- Custom message types. (Planned)
- Parameter distribution which enables dynamic reconfigure of software components. (Planned)
- Recording and playback of message passings with time encoding. (Planned)

## Installation

To use this package, you can add it as a dependency in your Swift package manager manifest file.

```swift
dependencies: [
    .package(url: "https://github.com/danielriege/swiftrobot.git", from: "0.1.0")
]
```

## Example
To use the `SwiftRobotClient` class, you can create an instance of the class and call its methods to publish and subscribe to messages. 

### local message passing

```swift
let client = SwiftRobotClient()

client.subscribe(channel: 0x01) { (msg: base_msg.UInt8Array) in
   // do things with the msg
}

let pubMsg = base_msg.UInt8Array(data: [0xbe, 0xef])
client.publish(channel: 0x01, msg: pubMsg)
```
**Note:** For best practices it is advised to only use one `SwiftRobotClient` instance per process, so shared memory is used and the bytes don't go through the kernel.

### local and network based message passing
```swift
let client = SwiftRobotClient()

client.start()

client.subscribe(channel: 0x00) { (msg: internal_msg.UpdateMsg) in
   print("Client \(msg.clientID) is now \(msg.status)")
}
```
Using the `start()` method the client will advertise its service using bonjour in the local domain with the `_swiftrobot._tcp` type. Additionally, it will start listening for incomming connections and connect to other clients in a pre-existing network. 

**Note:** On channel 0 informations about other client connections will be published. 

## License

This package is licensed under the MIT license. See the LICENSE file for more information.
