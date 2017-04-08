//
//  ViewController.swift
//  ExtendaBLE-OSX-Demo
//
//  Created by Anton on 3/31/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import CoreBluetooth

enum ControllerConfig : Int {
    case central, peripheral, both, sensor
    
    public static var configForOS : ControllerConfig {
        get {
            #if os(OSX)
                return .central
            #elseif os(tvOS)
                return .peripheral
            #else
                if UIDevice.current.name == "iPhone 6Plus" {
                    return .central
                }
                return .peripheral
            #endif
        }
    }
}

let dataServiceUUIDKey                 = "3C215EBB-D3EF-4D7E-8E00-A700DFD6E9EF"
let dataServiceCharacteristicUUIDKey   = "830FEB83-C879-4B14-92E0-DF8CCDDD8D8F"

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
        
        switch ControllerConfig.configForOS {
        case .central:
            configureDataServiceCentalManager()
        case .peripheral:
            configureDataServicePeripheralManager()
        case .both:
            configureDataServiceCentalManager()
            configureDataServicePeripheralManager()
        case .sensor:
            configureSensorCentralManager()
        }
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
                        print("\nVALUES MATCHED \n")
                    }
                    
                    /* Callback whenever the value is updated by the CENTRAL */
                    print("\nPreripheral Received read Value with : \n\n\(String(describing: valueString))\n")
                    
                    }.properties([.read, .write, .notify]).permissions([.readable, .writeable]).chunkingEnabled(true)
            }
        }.startAdvertising()
        
        #endif
    }
    
    func configureDataServiceCentalManager() {
        
        central = ExtendaBLE.newCentralManager() { (manager) in
            
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
            print("\nCentral Wrote Value : \n\n\(String(describing: valueString))\n")

            
            /* Callback when write is Complete, Next Perform Read From Peripheral as an Example */
            
            self.central?.read(fromUUID: dataServiceCharacteristicUUIDKey) { (returnedData, error) in
               
                let valueString = String(data: returnedData!, encoding: .utf8)
                print("\nCentral read Value with : \n\n\(String(describing: valueString))\n")
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
                
                print("\nRead Callback \n\n\(String(describing: returnedData))  - \(String(describing: error))\n\n")
                
                if let value = returnedData?.int16Value(0..<2) {
                    
                    print("\nRead Callback \n\n\(value)\n\n")
                }
            }
        }
    }
}


#if os(OSX)
    import Cocoa
    
    class ViewController: NSViewController  {
        var central : EBCentralManager?
        var peripheral : EBPeripheralManager?
        
        override func viewDidAppear() {
            super.viewDidAppear()
            configureServices()
        }
    }
#else
    import UIKit
    
    class ViewController: UIViewController  {
        var central : EBCentralManager?
        #if !os(tvOS)
        var peripheral : EBPeripheralManager?
        #endif
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configureServices()
        }
    }
#endif

