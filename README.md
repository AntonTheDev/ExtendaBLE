# ExtendaBLE

[![Cocoapods Compatible](https://img.shields.io/badge/pod-v0.2-blue.svg)]()
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)]()
[![Platform](https://img.shields.io/badge/platform-iOS%20|%20tvOS%20|%20OSX-lightgrey.svg)]()
[![License](https://img.shields.io/badge/license-MIT-343434.svg)](/LICENSE.md)

**NOTE: 11/06/2017 - Still In Beta, currently being updated w/ unit tests, documentatiom, and configured for cocoapods / carthage** 

## Introduction

Blocks Based BLE Client to streamline BLE communication between configured for Peripherals and centrals.

## Features

- [x] Blocks Syntax for Building Centrals and Peripherals
- [x] Callbacks for responding to, read and write, characteristic changes
- [x] Packet Based Payload transfer using negotiated MTU sizes

## Installation

* **Requirements** : XCode 8.0+, iOS 9.0+, tvOS 9.0+, OSX 10.10+
* [Installation Instructions](/Documentation/installation.md)
* [Release Notes](/Documentation/release_notes.md)

## Communication

- If you **found a bug**, or **have a feature request**, open an issue.
- If you **need help** or a **general question**, use [Stack Overflow](http://stackoverflow.com/questions/tagged/extenda-ble). (tag 'extenda-ble')
- If you **want to contribute**, review the [Contribution Guidelines](/Documentation/CONTRIBUTING.md), and submit a pull request.

## Basic Use

**ExtendaBLE** provides a very flexible syntax for defining centrals, and peripherals with ease. Following a blocks based builder approach you can easily define an centrals, peripherals, associated services and characteristics in minutes. With a blocks based syntax, it makes it very easy to listen for characteristic changes, and respond to them accordingly.

One of the unique features of **ExtendaBLE** is that it allows to bypass the limitations of the MTU size in communicating between devices. The library negotiates a common MTU size, and allows breaks down the data to be sent between devices into packets, which are then reconstructed by the receiving entity.

### Configuring Peripheral Manager

```swift
let dataServiceUUIDKey                  = "3C215EBB-D3EF-4D7E-8E00-A700DFD6E9EF"
let dataServiceCharacteristicUUIDKey    = "830FEB83-C879-4B14-92E0-DF8CCDDD8D8F"

/* Create Peripheral Manager advertise device as central */

peripheral = ExtendaBLE.newPeripheralManager { (manager) in
    
    manager.addService(dataServiceUUIDKey) { (service) in
        
        service.addCharacteristic(dataServiceCharacteristicUUIDKey) { (characteristic) in

            characteristic.properties([.read, .write, .notify]).permissions([.readable, .writeable])
            characteristic.packetsEnabled(true)
                
            characteristic.onUpdate { (data, error) in
                /* Called whenever the value is updated by the CENTRAL */
            }
        }
    }
}

peripheral?.startAdvertising()
```

### Configuring Central Manager

```swift
let dataServiceUUIDKey                  = "3C215EBB-D3EF-4D7E-8E00-A700DFD6E9EF"
let dataServiceCharacteristicUUIDKey    = "830FEB83-C879-4B14-92E0-DF8CCDDD8D8F"

central = ExtendaBLE.newCentralManager { (manager) in

    manager.reconnectOnStart(false)

    manager.addService(dataServiceUUIDKey) {(service) in

        service.addCharacteristic(dataServiceCharacteristicUUIDKey) { (characteristic) in
            
            characteristic.properties([.read, .write, .notify])
            characteristic.permissions([.readable, .writeable])
            characteristic.packetsEnabled(true)
            
            characteristic.onUpdate { (data, error) in
                /* Callback when ever the value is updated by the PERIPHERAL */
            }
        }

    }.onPeripheralConnectionChange{ (connected, peripheral, error) in
        /* Perform Read Transaction upon connecting */
    }
}

central?.startScan()
```

### Perform Write - Central Manager 

```swift 
central?.write(data: largeStringData, toUUID: dataServiceCharacteristicUUIDKey) { (writtenData, error) in        
    /* Do something upon successful write operation */
} 
```

### Perform Read - Central Manager 

```swift
self.central?.read(characteristicUUID: dataServiceCharacteristicUUIDKey) { (returnedData, error) in
    let valueString = String(data: returnedData!, encoding: .utf8)!
    /* Do something upon successful read operation */  
}
```
