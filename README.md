# SwiftRobot Middleware

## Overview

SwiftRobot is a lightweight and easy-to-use middleware for robotic applications. It provides a simple and efficient way to communicate between different components of a robot's software stack, allowing for seamless integration and rapid development.

One unique feature of SwiftRobot is its ability to communicate with iOS devices via USB, via the swiftrobotc implementation. This allows for an easy and real-time usable integration of iPhones and iPads as sensors, controllers, or displays for your robot.

With SwiftRobot's publish/subscribe messaging system, you can easily build distributed systems for robots. This package includes a Swift implementation of the middleware, and it can be used to communicate between different processes on the same machine or across a local network. SwiftRobot uses Bonjour for automatic discovery of other SwiftRobot clients on the local network, making it easy to set up and use without the need for manual configuration.

## Installation

To use this package, you can add it as a dependency in your Swift package manager manifest file.

```swift
dependencies: [
    .package(url: "https://github.com/danielriege/swiftrobot.git", from: "0.1.0")
]
```

## Usage

To use the `SwiftRobotClient` class, you can create an instance of the class and call its methods to publish and subscribe to messages. Note: For best practices it is advised to only use one `SwiftRobotClient` instance per application. The following is an example of how to use the `SwiftRobotClient`

```swift
//TODO
```
