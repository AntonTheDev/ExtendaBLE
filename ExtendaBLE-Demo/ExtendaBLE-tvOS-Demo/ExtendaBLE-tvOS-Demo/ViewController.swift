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

let sensorServiceUUID                   = "F000AA00-0451-4000-B000-000000000000"
let sensorConfigCharacteristicUUID      = "F000AA01-0451-4000-B000-000000000000"
let sensorValueCharacteristicUUID       = "F000AA02-0451-4000-B000-000000000000"

class ViewController: UIViewController {
    
    var central : EBCentralManager?
    
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
        /* Not Available in tvOS */
    }
    
    func configureSliceServiceCentralManager() {
        
        central = ExtendaBLE.newCentralManager() { (manager) in
            
            manager.addService(sliceServiceUUIDKey) {(service) in
                service.addProperty(sensorValueCharacteristicUUID).properties([.read]).permissions([.readable])
                service.addProperty(sensorConfigCharacteristicUUID).properties([.write]).permissions([.writeable])
            }
            
            }.onPeripheralConnectionChange{ (connected, peripheral, error) in
                if connected {
                    self.performSliceServiceReadWrite()
                }
            }.startScan()
    }
    
    func performSliceServiceReadWrite() {
        
        let configBytes: [UInt8] = [1]
        
        central?.write(data: Data(bytes : configBytes), toUUID: sensorConfigCharacteristicUUID) { (writtenData, error) in
            
            self.central?.read(fromUUID: sensorValueCharacteristicUUID) { (returnedData, error) in
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
                if let value = returnedData?.int16Value(0..<2) {
                    print("\nRead Callback \n\n\(value)\n\n")
                }
            }
        }
    }
}

