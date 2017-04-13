//
//  ViewController.swift
//  ExtendaBLE-OSX-Demo
//
//  Created by Anton on 3/31/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import CoreBluetooth

enum ControllerConfig : Int {
    case central, peripheral, both, sensor, bluebean
    
    public static var configForOS : ControllerConfig {
        get {
            #if os(OSX)
                return .bluebean
            #elseif os(tvOS)
                return .central
            #else
                if UIDevice.current.name == "iPhone 6Plus" {
                    return .central
                }
                return .central
            #endif
        }
    }
}

let dataServiceUUIDKey                  = "3C215EBB-D3EF-4D7E-8E00-A700DFD6E9EF"
let dataServiceCharacteristicUUIDKey    = "830FEB83-C879-4B14-92E0-DF8CCDDD8D8F"

let beanTransportService                = "A495FF10-C5B1-4B44-B512-1370F02D74DE"
let beanTransportCharacteristicUUID     = "A495FF11-C5B1-4B44-B512-1370F02D74DE"

let beanScratchServiceUUIDKey           = "a495ff20-c5b1-4b44-b512-1370f02d74de"

let beanScratchCharacteristic1UUIDKey   = "a495ff21-c5b1-4b44-b512-1370f02d74de"
let beanScratchCharacteristic2UUIDKey   = "a495ff22-c5b1-4b44-b512-1370f02d74de"
let beanScratchCharacteristic3UUIDKey   = "a495ff23-c5b1-4b44-b512-1370f02d74de"
let beanScratchCharacteristic4UUIDKey   = "a495ff24-c5b1-4b44-b512-1370f02d74de"
let beanScratchCharacteristic5UUIDKey   = "a495ff25-c5b1-4b44-b512-1370f02d74de"

let sensorServiceUUID                   = "F000AA00-0451-4000-B000-000000000000"
let sensorConfigCharacteristicUUID      = "F000AA02-0451-4000-B000-000000000000"
let sensorValueCharacteristicUUID       = "F000AA01-0451-4000-B000-000000000000"

extension ViewController {
    
    var testValueString : String {
        get {
            return "Hello this is a faily long string to check how many bytes lets make this a lot longer even longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer XXXXXXXXXXXXXXXX"
        }
    }
    
    func configureServices() {
        
        ExtendaBLE.setLogLevel(.debug)
        
        switch ControllerConfig.configForOS {
        case .central:
            configureDataServiceCentalManager()
        case .peripheral:
            configureDataServicePeripheralManager()
        case .bluebean:
            configureBlueBeanCentralManager()
        case .both:
            configureDataServiceCentalManager()
            configureDataServicePeripheralManager()
        case .sensor:
            configureSensorCentralManager()
        }
    }
    
    func triggerUpdate() {
        
    }
}


// MARK: - Slice Logic (Splitting a large Data Stream into Packets)

extension ViewController {
    
    func configureDataServicePeripheralManager() {
        
        #if os(tvOS)
            return
        #else
            
            /* Create Peripheral Manager advertise device as central */
            
            peripheral = ExtendaBLE.newPeripheralManager() { (manager) in
                
                manager.localName("Test Peripheral")
                manager.addService(dataServiceUUIDKey) {(service) in
                    
                    service.addProperty(dataServiceCharacteristicUUIDKey).onUpdate { (data, error) in
                        
                        let valueString = String(data: data!, encoding: .utf8)
                        
                        if self.testValueString == valueString {
                            Log(.debug, logString: "Successful Peripheral Update w/ value : \n\n\(String(describing: valueString))\n\n")
                        } else {
                            Log(.debug, logString: "Failed Peripheral Update w/ value : \n\n\(String(describing: valueString))\n\n")
                        }
                        
                        }.properties([.read, .write, .notify]).permissions([.readable, .writeable]).chunkingEnabled(true)
                }
                }.startAdvertising()
            
        #endif
    }
    
    func configureDataServiceCentalManager() {
        
        central = ExtendaBLE.newCentralManager() { (manager) in
            
            #if !os(OSX)
                manager.peripheralCacheKey("Peripheral Key")
            #endif
            manager.peripheralName = "Bean"
            manager.addService(dataServiceUUIDKey) {(service) in
                service.addProperty(dataServiceCharacteristicUUIDKey).onUpdate { (data, error) in
                    
                    
                    /* Callback when ever the value is updated by the PERIPHERAL */
                    
                    }.properties([.read, .write, .notify]).permissions([.readable, .writeable]).chunkingEnabled(true)
            }
            
            }.onPeripheralConnectionChange{ (connected, peripheral, error) in
                if connected {
                    self.performSliceServiceReadWrite()
                }
            }.startScan()
    }
    
    func performSliceServiceReadWrite() {
        
        guard let largeStringData = testValueString.data(using: .utf8) else {
            return
        }
        
        /* Perform Write From Peripheral */
        
        central?.write(data: largeStringData, toUUID: dataServiceCharacteristicUUIDKey) { (writtenData, error) in
            
            let valueString = String(data: writtenData!, encoding: .utf8)
            
            Log(.debug, logString: "Central Wrote Value : \n\n\(String(describing: valueString))\n\n")
            
            self.central?.read(fromUUID: dataServiceCharacteristicUUIDKey) { (returnedData, error) in
                
                let valueString = String(data: returnedData!, encoding: .utf8)
                
                if self.testValueString == valueString {
                    Log(.debug, logString: "Successful Central Read w/ value : \n\n\(String(describing: valueString))\n\n")
                } else {
                    Log(.debug, logString: "Failed Central Read w/ value : \n\n\(String(describing: valueString))\n\n")
                }
            }
        }
    }
}

// MARK: - Sensor Logic

extension ViewController {
    
    func configureSensorCentralManager() {
        
        central = ExtendaBLE.newCentralManager() { (manager) in
            
            manager.addService(sensorServiceUUID) {(service) in
                service.addProperty(sensorValueCharacteristicUUID).properties([.read]).permissions([.readable])
                service.addProperty(sensorConfigCharacteristicUUID).properties([.write]).permissions([.writeable])
            }
            
            }.onPeripheralConnectionChange{ (connected, peripheral, error) in
                
                if connected {
                    self.performSensorReadWrite()
                }
            }.startScan()
    }
    
    func performSensorReadWrite() {
        
        let configBytes: [UInt8] = [1]
        
        central?.write(data: Data(bytes : configBytes), toUUID: sensorConfigCharacteristicUUID) { (writtenData, error) in
            
            self.central?.read(fromUUID: sensorValueCharacteristicUUID) { (returnedData, error) in
                
                Log(.debug, logString: "\nRead Callback \n\n\(String(describing: returnedData))  - \(String(describing: error))\n\n")
                
                if let value = returnedData?.int16Value(inRange: 0..<2) {
                    
                    Log(.debug, logString: "\nRead Callback \n\n\(value)\n\n")
                }
            }
        }
    }
}


// MARK: - Sensor Logic

extension ViewController {
    
    func configureBlueBeanCentralManager() {
        
        central = ExtendaBLE.newCentralManager() { (manager) in
            
            manager.peripheralName = "Bean"
            manager.addService(beanScratchServiceUUIDKey) {(service) in
                service.addProperty(beanScratchCharacteristic1UUIDKey).properties([.read, .write, .notify,.writeWithoutResponse]).permissions([.readable, .writeable])
                service.addProperty(beanScratchCharacteristic2UUIDKey).properties([.read, .write, .notify,.writeWithoutResponse]).permissions([.readable, .writeable])
                
                service.addProperty(beanScratchCharacteristic3UUIDKey).properties([.read, .write, .notify,.writeWithoutResponse]).permissions([.readable, .writeable])
                
                service.addProperty(beanScratchCharacteristic4UUIDKey).properties([.read, .write, .notify,.writeWithoutResponse]).permissions([.readable, .writeable])
                service.addProperty(beanScratchCharacteristic5UUIDKey).properties([.read, .write, .notify,. writeWithoutResponse]).permissions([.readable, .writeable])
                
            }
            
            }.onPeripheralConnectionChange{ (connected, peripheral, error) in
                
                if connected {
                    self.performBlueBeanReadWrite()
                }
            }.startScan()
    }
    
    func performBlueBeanReadWrite() {
        
        self.central?.read(fromUUID: beanScratchCharacteristic1UUIDKey) { (returnedData, error) in
            if let value = returnedData?.int8Value(atIndex: 0) {
                Log(.debug, logString: "Read beanScratchCharacteristic1UUIDKey Callback \n\n\(String(describing: value))  - \(String(describing: error))\n")
            }
        }
        
        self.central?.read(fromUUID: beanScratchCharacteristic2UUIDKey) { (returnedData, error) in
            Log(.debug, logString: "Read beanScratchCharacteristic2UUIDKey Callback \n\n\(String(describing: returnedData))  - \(String(describing: error))\n")
        }
        
        self.central?.read(fromUUID: beanScratchCharacteristic3UUIDKey) { (returnedData, error) in
            
            Log(.debug, logString: "Read beanScratchCharacteristic3UUIDKey Callback \n\n\(String(describing: returnedData))  - \(String(describing: error))\n")
        }
        
        self.central?.read(fromUUID: beanScratchCharacteristic4UUIDKey) { (returnedData, error) in
            
            Log(.debug, logString: "Read beanScratchCharacteristic4UUIDKey Callback \n\n\(String(describing: returnedData))  - \(String(describing: error))\n")
        }
        
        self.central?.read(fromUUID: beanScratchCharacteristic5UUIDKey) { (returnedData, error) in
            
            Log(.debug, logString: "Read beanScratchCharacteristic5UUIDKey Callback \n\n\(String(describing: returnedData))  - \(String(describing: error))\n")
        }
    }
}


#if os(OSX)
    import Cocoa
    
    class ViewController: NSViewController  {
        var central : EBCentralManager?
        var peripheral : EBPeripheralManager?
        
        override func viewWillAppear() {
            super.viewWillAppear()
            view.addSubview(peripheralUpdatebutton)
            peripheralUpdatebutton.frame = CGRect(x: (view.bounds.width / 2.0) - 100, y: (view.bounds.height / 2.0) - 30, width: 200, height: 60)
        }
        
        override func viewDidAppear() {
            super.viewDidAppear()
            configureServices()
        }
        
        lazy var peripheralUpdatebutton : NSButton = {
            var button = NSButton()
            button.action = #selector(triggerUpdate)
            button.title = "Update Peripheral"
            return button
        }()
    }
#else
    import UIKit
    
    class ViewController: UIViewController  {
        var central : EBCentralManager?
        #if !os(tvOS)
        var peripheral : EBPeripheralManager?
        #endif
        
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            view.addSubview(peripheralUpdatebutton)
            peripheralUpdatebutton.frame = CGRect(x: 0, y: 0, width: 200, height: 60)
            peripheralUpdatebutton.center = view.center
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configureServices()
        }
        
        lazy var peripheralUpdatebutton : UIButton = {
            var button = UIButton()
            button.addTarget(self, action: #selector(triggerUpdate), for: .touchUpInside)
            button.setTitle("Update Peripheral", for: .normal)
            return button
        }()
    }
#endif

