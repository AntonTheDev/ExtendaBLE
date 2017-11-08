# ExtendaBLE

[![Cocoapods Compatible](https://img.shields.io/badge/pod-v0.2-blue.svg)]()
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)]()
[![Platform](https://img.shields.io/badge/platform-iOS%20|%20tvOS%20|%20OSX-lightgrey.svg)]()
[![License](https://img.shields.io/badge/license-MIT-343434.svg)](/LICENSE.md)

![alt tag](/Documentation/extendable_header.png?raw=true)

## Introduction

**ExtendaBLE** provides a very flexible syntax for defining centrals and peripherals with ease. Following a blocks based builder approach you can easily create centrals, peripherals, associated services, characteristics, and define callbacks to listen for characteristic changes accordingly.

One of the unique features of **ExtendaBLE** is that it allows to bypass the limitations of the MTU size in communicating between devices. The library negotiates a common MTU size, and allows breaks down the data to be sent between devices into packets, which are then reconstructed by the receiving entity.

## Features

- [x] Blocks Syntax for Building Centrals and Peripherals
- [x] Callbacks for responding to, read and write, characteristic changes
- [x] Packet Based Payload transfer using negotiated MTU sizes
- [x] Characteristic Update Callbacks
- [x] Streamlined parsing for characteristic read operations

## Installation

* **Requirements** : XCode 9.0+, iOS 9.0+, tvOS 9.0+, OSX 10.10+
* [Installation Instructions](/Documentation/installation.md)
* [Release Notes](/Documentation/release_notes.md)

## Communication

- If you **found a bug**, or **have a feature request**, open an issue.
- If you **need help** or a **general question**, use [Stack Overflow](http://stackoverflow.com/questions/tagged/extenda-ble). (tag 'extenda-ble')
- If you **want to contribute**, review the [Contribution Guidelines](/Documentation/CONTRIBUTING.md), and submit a pull request.

## Basic Setup

In configuring BLE the first step is to configure a unique UUID for the shared a for the service(s) and characteristic(s) to intercommunicate between the peripheral & central.

For the purposes of documentation, the following constants will be shared across the configuration examples

```swift
let dataServiceUUIDKey                  = "3C215EBB-D3EF-4D7E-8E00-A700DFD6E9EF"
let dataServiceCharacteristicUUIDKey    = "830FEB83-C879-4B14-92E0-DF8CCDDD8D8F"
```

If you are not familiar with how BLE works, please review the [Core Bluetooth Programming Guide](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/AboutCoreBluetooth/Introduction.html) before continuing.

### Peripheral Manager

In it's simplest form, the following is an example of how to configure peripheral using a simple blocks based syntax.

```swift
peripheral = ExtendaBLE.newPeripheralManager { (manager) in

    manager.addService(dataServiceUUIDKey) { (service) in
        service.addCharacteristic(dataServiceCharacteristicUUIDKey) { (characteristic) in
            characteristic.properties([.read, .write]).permissions([.readable, .writeable])
        }
    }
}
```

#### Begin Advertising

To start advertising services and their respective characteristics, just call on ``startAdvertising()`` on the peripheral created in the prior section.

```swift
peripheral?.startAdvertising()
```

#### Responding to Updates

If you would like to respond to characteristic updates on the peripheral when a central updates a value, define an ``onUpdate  { (data, error) in }`` per characteristic accordingly. When the Central finishes updating the value, the callback will be triggered.

```swift
peripheral = ExtendaBLE.newPeripheralManager { (manager) in
    manager.addService(dataServiceUUIDKey) { (service) in

        service.addCharacteristic(dataServiceCharacteristicUUIDKey) { (characteristic) in
            characteristic.properties([.read, .write, .notify]).permissions([.readable, .writeable])                

            characteristic.onUpdate { (data, error) in
                /* Called whenever the value is updated by the CENTRAL */
            }
        }
    }
}
```

#### Notifying Central

If you would like the peripheral to retain a connection for a specific characteristic, and notify the connected central manager when the value is updated, when configuring the properties, ensure to include the ``.notify`` CBCharacteristicProperty in the definition as follows.

```swift
peripheral = ExtendaBLE.newPeripheralManager { (manager) in

    manager.addService(dataServiceUUIDKey) { (service) in
        service.addCharacteristic(dataServiceCharacteristicUUIDKey) { (characteristic) in
            characteristic.properties([.read, .write, .notify]).permissions([.readable, .writeable])
        }
    }
}
```

### Central Manager

In it's simplest form, the following is an example of how to configure central manager using a simple blocks based syntax.

```swift
central = ExtendaBLE.newCentralManager { (manager) in

    manager.addService(dataServiceUUIDKey) {(service) in
        service.addCharacteristic(dataServiceCharacteristicUUIDKey) { (characteristic) in
            characteristic.properties([.read, .write]).permissions([.readable, .writeable])
        }
    }
}
```

#### Begin Scanning

Start scanning for peripheral(s) defined with the services, and their respective characteristics, just call on ``startScan()`` on the central created in the prior section. The central will auto connect to the peripheral when found.

```swift
central?.startScan()
```

#### Responding to State Changes

Responding to stages of the scanning operation, the following callbacks can be defined for the manager.

```swift
central = ExtendaBLE.newCentralManager { (manager) in

    manager.addService(dataServiceUUIDKey) {(service) in
        /* Characteristic Definitions */
    }.onPeripheralConnectionChange{ (connected, peripheral, error) in
        /* Respond to Successful Connection */
    }.onDidDiscover { (central, advertisementData, rssi) in
        /* Respond to Discovered Services */
    }.onStateChange { (state) in
        /* Respond to State Changes */
    }
}
```

#### Respond to Successful Connection

To perform a Read/Write upon connecting to a peripheral, define a callback as follows to be notified of the successful connection.

```swift
central = ExtendaBLE.newCentralManager { (manager) in

    manager.addService(dataServiceUUIDKey) {(service) in
        service.addCharacteristic(dataServiceCharacteristicUUIDKey) { (characteristic) in
            characteristic.properties([.read, .write]).permissions([.readable, .writeable])
        }
    }.onPeripheralConnectionChange{ (connected, peripheral, error) in
        /* Perform Read Transaction upon connecting */
    }
}
```

#### Responding to Update Notification

If you would like to retain a connection for a specific characteristic, and be notified by the peripheral when the value is updated, when configuring the properties, ensure to include the ``.notify`` CBCharacteristicProperty in the definition as follows, and create a call back to respond to the change.

```swift
peripheral = ExtendaBLE.newPeripheralManager { (manager) in

    manager.addService(dataServiceUUIDKey) { (service) in
        service.addCharacteristic(dataServiceCharacteristicUUIDKey) { (characteristic) in
            characteristic.properties([.read, .write, .notify]).permissions([.readable, .writeable])

            characteristic.onUpdate { (data, error) in
                /* Called whenever the value is updated by the PERIPHERAL */
            }
        }
    }
}
```

#### Perform Write

To perform a write for a specific characteristic for a connected peripheral, call the ``write(..)`` on the central, and with the content to write, and the characteristicUUID to write to. The callback will be triggered once the write is complete.  

```swift
central?.write(data: stringData, toUUID: dataServiceCharacteristicUUIDKey) { (writtenData, error) in    

    /* Do something upon successful write operation */
}
```

#### Perform Read

To perform a read for a specific characteristic for a connected peripheral, call the ``read(..)`` on the central, and with  the characteristicUUID to read. The callback will be triggered once the read is complete with the ``Data`` read, or an error if the operation failed.

```swift
central?.read(characteristicUUID: dataServiceCharacteristicUUIDKey) { (returnedData, error) in
    let valueString = String(data: returnedData!, encoding: .utf8)?

    /* Do something upon successful read operation */  
}
```

### Packet Based Communication

BLE has a limitation as to how much data can be sent between devices relative to the MTU size. To enabled the ability for the central and peripheral to communicate characteristic data greater in size than this limitation, **ExtendaBLE** provides the ability to use packets to breakup and rebuild the data when communicating between devices.

To enable the ability to send data greater than the MTU limitation of BLE, set the ``packetsEnabled`` to true on both the peripheral and the central. This will ensure that when communications occurs, the data is broken up into individual packets which will be sent across and rebuilt once the operation is complete.  

```swift
peripheral = ExtendaBLE.newPeripheralManager { (manager) in

    manager.addService(dataServiceUUIDKey) { (service) in
        service.addCharacteristic(dataServiceCharacteristicUUIDKey) { (characteristic) in
            characteristic.properties([.read, .write])
            characteristic.permissions([.readable, .writeable])
            characteristic.packetsEnabled(true)
        }
    }
}

central = ExtendaBLE.newCentralManager { (manager) in

    manager.addService(dataServiceUUIDKey) {(service) in
        service.addCharacteristic(dataServiceCharacteristicUUIDKey) { (characteristic) in
            characteristic.properties([.read, .write])
            characteristic.permissions([.readable, .writeable])     
            characteristic.packetsEnabled(true)
        }
    }
}
```


### Extracting Data from Byte Stream

When communicating reading from physical peripheral, generally the specifications will return a byte stream, and will identify where different types of data are located, and it is up to the developer to extract and covert specific parts of the returned data. With **ExtendaBLE** and extension is included to easily extract data from such streams. The following methods can be called on the returned ``Data`` instance with a specified start index to extract the following types of data.

```swift
public func int8Value(atIndex : Int) -> Int8?
public func int16Value(atIndex : Int) -> Int16?
public func int32Value(atIndex : Int) -> Int32?
public func int64Value(atIndex : Int) -> Int64?
public func uint8Value(atIndex : Int) -> UInt8?
public func uint16Value(atIndex : Int) -> UInt16?
public func uint32Value(atIndex : Int) -> UInt32?
public func uint64Value(atIndex : Int) -> UInt64?
public func stringValue(atIndex : Int) -> String?
```

If finer control is needed, ranges can be used to extract specific data from the stream as follows.

```swift
public func int8Value(inRange range : Range<Data.Index>) -> Int8?
public func int16Value(inRange range : Range<Data.Index>) -> Int16?
public func int32Value(inRange range : Range<Data.Index>) -> Int32?
public func int64Value(inRange range : Range<Data.Index>) -> Int64?
public func uint8Value(inRange range : Range<Data.Index>) -> UInt8?
public func uint16Value(inRange range : Range<Data.Index>) -> UInt16?
public func uint32Value(inRange range : Range<Data.Index>) -> UInt32?
public func uint64Value(inRange range : Range<Data.Index>) -> UInt64?
public func doubleValue(inRange range : Range<Data.Index>) -> Double?
public func floatValue(inRange range : Range<Data.Index>) -> Float?
public func stringValue(inRange range : Range<Data.Index>) -> String?
```
