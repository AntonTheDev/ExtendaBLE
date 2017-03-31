//
//  ViewController.swift
//  ExtendaBLE-OSX-Demo
//
//  Created by Anton on 3/31/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Cocoa
import CoreBluetooth


let sliceServiceUUIDKey                 = "3C215EBB-D3EF-4D7E-8E00-A700DFD6E9EF"
let sliceServiceCharacteristicUUIDKey   = "830FEB83-C879-4B14-92E0-DF8CCDDD8D8F"

let sensorServiceUUID                   = "F000AA00-0451-4000-B000-000000000000"
let sensorConfigCharacteristicUUID      = "F000AA02-0451-4000-B000-000000000000"
let sensorValueCharacteristicUUID       = "F000AA01-0451-4000-B000-000000000000"

class ViewController: NSViewController {
    
    var central : EBCentralManager?
    var peripheral : EBPeripheralManager?
    
    let testValueString = "Hello this is a faily long string to check how many bytes lets make this a lot longer even longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer XXXXXXXXXXXXXXXX"
    
    
    override func viewDidAppear() {
        
        super.viewDidAppear()
        
     //   if UIDevice.current.name == "iPhone 6Plus" {
     //       configureSliceServicePeripheralManager()
     //   } else {
          //  configureSensorCentralManager()
     //   }
        
        
            configureSliceServiceCentralManager()
        
        
        /*
         
         let valueString = String(data: data, encoding: .utf8)
         print("\nPeripheral Updated Value with : \n\n\(String(describing: valueString))\n")

 */
    }
}



// MARK: - Slice Logic (Splitting a large Data Stream into Packets)

extension ViewController {
    
    func configureSliceServicePeripheralManager() {
        
        /* Create Peripheral Manager advertise device as central */
        
        peripheral = ExtendaBLE.newPeripheralManager() { (manager) in
            
            manager.localName("Test Peripheral")
            manager.addService(sliceServiceUUIDKey) {(service) in
                
                service.addProperty(sliceServiceCharacteristicUUIDKey).onUpdate { (data, error) in
    
                    /* Callback whenever the value is updated by the CENTRAL */
                    
                    }.properties([.read, .write, .notify]).permissions([.readable, .writeable]).chunkingEnabled(true)
            }
        }.startAdvertising()
    }
    
    func configureSliceServiceCentralManager() {
        
        central = ExtendaBLE.newCentralManager() { (manager) in
            
            manager.addService(sliceServiceUUIDKey) {(service) in
                service.addProperty(sliceServiceCharacteristicUUIDKey).onUpdate { (data, error) in
                    
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
        
        central?.write(data: largeStringData, toUUID: sliceServiceCharacteristicUUIDKey) { (writtenData, error) in
            
            let valueString = String(data: writtenData!, encoding: .utf8)
            print("\nCentral Wrote Value : \n\n\(String(describing: valueString))\n")

            
            /* Callback when write is Complete, Next Perform Read From Peripheral as an Example */
            
            self.central?.read(fromUUID: sliceServiceCharacteristicUUIDKey) { (returnedData, error) in
               
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
                
                print("\nRead Callback \n\n\(returnedData)  - \(String(describing: error))\n\n")
                
                if let value = returnedData?.int16Value(0..<2) {
                    print("\nRead Callback \n\n\(value)\n\n")
                }
            }
        }
    }
}

