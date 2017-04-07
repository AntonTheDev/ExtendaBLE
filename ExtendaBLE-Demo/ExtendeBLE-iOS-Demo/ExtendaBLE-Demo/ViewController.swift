//
//  ViewController.swift
//  ExtendaBLE-Demo
//
//  Created by Anton on 3/30/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import UIKit
import CoreBluetooth


let sliceServiceUUIDKey                 = "3C215EBB-D3EF-4D7E-8E00-A700DFD6E9EF"
let sliceServiceCharacteristicUUIDKey   = "830FEB83-C879-4B14-92E0-DF8CCDDD8D8F"
let sliceServiceCharacteristicUUIDKey2  = "B8A6F32B-3E1B-42AB-8CDA-24C221AD3F0C"

let sensorServiceUUID                   = "F000AA00-0451-4000-B000-000000000000"
let sensorConfigCharacteristicUUID      = "F000AA01-0451-4000-B000-000000000000"
let sensorValueCharacteristicUUID       = "F000AA02-0451-4000-B000-000000000000"

class ViewController: UIViewController {

    var centralManager : EBCentralManager?
    var peripheral : EBPeripheralManager?
    
    let testValueString = "Hello this is a faily long string to check how many bytes lets make this a lot longer even longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer XXXXXXXXXXXXXXXX"
    

    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
     //   if UIDevice.current.name == "iPhone 6Plus" {
            configureSliceServicePeripheralManager()
    //    } else {
    //        configureSensorCentralManager()
    //    }
    }
}



// MARK: - Slice Logic (Splitting a large Data Stream into Packets)

extension ViewController {
    
    func configureSliceServicePeripheralManager() {
        
        /* Create Peripheral Manager advertise device as central */
        
        peripheral = ExtendaBLE.newPeripheralManager() { (manager) in
            manager.localName(UIDevice.current.name)
            manager.addService(sliceServiceUUIDKey) {(service) in
                
                service.addProperty(sliceServiceCharacteristicUUIDKey).onUpdate { (data, error) in
                    let valueString = String(data: data!, encoding: .utf8)
                    
                    print("\nPeripheral Updated Value with : \n\n\(String(describing: valueString))\n")
                    
                    }.properties([.read, .write, .notify]).permissions([.readable, .writeable]).chunkingEnabled(true)
            }
            
            }.startAdvertising()
    }
    
    func configureSliceServiceCentralManager() {
     
        centralManager = ExtendaBLE.newCentralManager() { (manager) in
            
            manager.addService(sliceServiceUUIDKey) {(service) in
                service.addProperty(sliceServiceCharacteristicUUIDKey).onUpdate { (data, error) in
                    let valueString = String(data: data!, encoding: .utf8)
                    
                    print("\nCentral Updated Value with : \n\n\(String(describing: valueString))\n")
                    
                }.properties([.read, .write, .notify]).permissions([.readable, .writeable])

            }
        }.onPeripheralConnectionChange{ (connected, peripheral, error) in
            if connected {
                self.performSliceServiceReadWrite()
            }
        }
        
        centralManager?.startScan()
    }
    
    func performSliceServiceReadWrite() {
        
        let configBytes: [UInt8] = [1]
        
        centralManager?.write(data: Data(bytes : configBytes), toUUID: sensorConfigCharacteristicUUID) { (writtenData, error) in
            
            self.centralManager?.read(fromUUID: sensorValueCharacteristicUUID) { (returnedData, error) in
                if let value = returnedData?.int16Value(0..<2) {
                    print("\nRead Callback \n\n\(value)\n\n")
                }
            }
        }
    }
}

// MARK: - Sensor Logic

extension ViewController {
    
    func configureSensorCentralManager() {
        
        centralManager = ExtendaBLE.newCentralManager() { (manager) in
            
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
        
        centralManager?.write(data: Data(bytes : configBytes), toUUID: sensorConfigCharacteristicUUID) { (writtenData, error) in
            
            self.centralManager?.read(fromUUID: sensorValueCharacteristicUUID) { (returnedData, error) in
                
                if let value = returnedData?.int16Value(0..<2) {
                    print("\nRead Callback \n\n\(value)\n\n")
                }
            }
        }
    }
}

