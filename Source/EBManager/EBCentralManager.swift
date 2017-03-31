//
//  EBCentralManager.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

public typealias CentralManagerStateChangeCallback = ((_ state: CBManagerState) -> Void)
public typealias CentralManagerDidDiscoverCallback = ((_ peripheral: CBPeripheral, _ advertisementData: [String : Any], _ rssi: NSNumber) -> Void)
public typealias CentralManagerPeripheralConnectionCallback = ((_ connected : Bool, _ peripheral: CBPeripheral, _ error: Error?) -> Void)

public class EBCentralManager : NSObject {
    
    internal var centralManager : CBCentralManager
    
    internal var mtuValue : Int16 = 0
    
    internal var services = [CBMutableService]()
    internal var packetServices = [CBMutableService]()
    internal var connectedCharacteristics = [CBPeripheral : [CBCharacteristic]]()
    
    internal var registeredCharacteristicUpdateCallbacks  = [CBUUID : EBTransactionCallback]()
    
    internal var activeWriteTransations = [CBPeripheral : [Transaction]]()
    internal var activeReadTransations  = [CBPeripheral : [Transaction]]()
    
    internal var stateChangeCallBack          : CentralManagerStateChangeCallback?
    internal var didDiscoverCallBack          : CentralManagerDidDiscoverCallback?
    internal var peripheralConnectionCallback : CentralManagerPeripheralConnectionCallback?
    
    public required init(queue: DispatchQueue? = nil,  options: [String : Any]? = nil) {
        centralManager = CBCentralManager(delegate: nil, queue: queue, options: options)
        super.init()
        centralManager.delegate = self
    }
}

extension EBCentralManager {
    
    public var isScanning: Bool {
        get { return centralManager.isScanning }
    }

    @discardableResult public func startScan(allowDuplicates : Bool = true) ->  EBCentralManager {
        if centralManager.state != .poweredOn {
            return self
        }
        
        let registeredServicesUUIDs = services.map { $0.uuid }
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        return self
    }
    
    @discardableResult public func stopScan() -> EBCentralManager {
        centralManager.stopScan()
        return self
    }
    
    public func write(data : Data, toUUID uuid: String, completion : EBTransactionCallback? = nil) {

        for (peripheral, characteristics) in connectedCharacteristics {
            
            if let characteristic = characteristics.first(where: { $0.uuid.uuidString == uuid }) {
                
             //   let chunks = data.packetArray(withMTUSize : mtuValue)
        
                let transaction = Transaction()
                
                transaction.data = data
             //   transaction.responseCount = chunks.count
                transaction.characteristic = characteristic
                transaction.completion = completion
                
                if activeWriteTransations[peripheral] == nil {
                    activeWriteTransations[peripheral] = [transaction]
                } else {
                    activeWriteTransations[peripheral]!.append(transaction)
                }
                
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
               /*
                for chunk in chunks {
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                }
                 */
            }
        }
    }
    
    public func read(fromUUID uuid: String, completion : EBTransactionCallback? = nil) {

        for (peripheral, characteristics) in connectedCharacteristics {
           
            if let characteristic = characteristics.first(where: { $0.uuid.uuidString == uuid }) {
               
                if activeReadTransations[peripheral]?.first(where: { $0.characteristic == characteristic }) == nil {
                    
                    if activeReadTransations[peripheral] == nil { activeReadTransations[peripheral] = [Transaction]() }
                    
                    let transaction = Transaction()
                    transaction.characteristic = characteristic
                    transaction.completion = completion
                    activeReadTransations[peripheral]!.append(transaction)
                }
            }
            
            guard let transactions = activeReadTransations[peripheral] else {
                    return
            }
            
            if let activeReadTransation = transactions.first(where: { $0.characteristic?.uuid.uuidString == uuid }) {
                
                if activeReadTransation.isComplete {
                    
                    let reconstructedValue = activeReadTransation.reconstructedValue
                    let characteristics = transactions.map { $0.characteristic!.uuid }
                    
                    if let index = characteristics.index(of : CBUUID(string :uuid)) {
                        activeReadTransations[peripheral]?.remove(at : index)
                    }
                    
                    if let completion = activeReadTransation.completion {
                        completion(reconstructedValue, nil)
                    } else {
                        registeredCharacteristicUpdateCallbacks[CBUUID(string :uuid)]?(reconstructedValue, nil)
                    }
                    
                    return
                }
            }
        }
        
        for (peripheral, characteristics) in connectedCharacteristics {
            if let characteristic = characteristics.first(where: { $0.uuid.uuidString == uuid }) {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    internal func handleReadTransation(forCharacteristic characteristic: CBCharacteristic, from peripheral: CBPeripheral) {
        
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
           
            guard let characteristics = service.characteristics,
                  let index = characteristics.index(of : characteristic),
                  let data = characteristics[index].value else {
                    return
            }

            guard let transactions = activeReadTransations[peripheral],
                  let transaction = transactions.first(where: { $0.characteristic == characteristic }) else {
                    return
            }
            
            transaction.responseCount = data.totalPackets
            transaction.chunks.append(data)
            
            read(fromUUID : characteristic.uuid.uuidString)
        }
    }
    
    func handleWriteTransationResponse(forCharacteristic characteristic: CBCharacteristic, from peripheral: CBPeripheral) {
        
        guard let transactions = activeWriteTransations[peripheral],
              let transaction = transactions.first(where: { $0.characteristic == characteristic }) else {
            return
        }
        
        transaction.responseCount =  transaction.responseCount - 1
        
     //   if transaction.responseCount == 0 {
            transaction.completion?(transaction.data!, nil)
            activeWriteTransations[peripheral] = nil
    //    }
    }
}

extension EBCentralManager {
    
    @discardableResult public func onStateChange(_ callback : @escaping CentralManagerStateChangeCallback) -> EBCentralManager {
        stateChangeCallBack = callback
        return self
    }
    
    @discardableResult public func onDidDiscover(_ callback : @escaping CentralManagerDidDiscoverCallback) -> EBCentralManager {
        didDiscoverCallBack = callback
        return self
    }
    
    @discardableResult public func onPeripheralConnectionChange(_ callback : @escaping CentralManagerPeripheralConnectionCallback) -> EBCentralManager {
        peripheralConnectionCallback = callback
        return self
    }
}

extension EBCentralManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .poweredOn:
            startScan()
        default:
            break;
        }
        
        print("\nCentral \(UIDevice.current.name) BLE state - \(central.state.rawValue)")
        stateChangeCallBack?(central.state)
    }
    
    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String : Any],
                               rssi RSSI: NSNumber) {
        
        if let localname = advertisementData[CBAdvertisementDataLocalNameKey] as? String , localname == "CC2650 SensorTag" {
           
          //  if localname = "CC2650 SensorTag" {
                print("\nDiscovered Services")
            
            if let peripheralUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
          
                
                for uuid in peripheralUUIDs {
                    print("        -  \(uuid.uuidString)")
                    
                    connectedCharacteristics[peripheral] = [CBCharacteristic]()
                    centralManager.connect(peripheral, options: nil)
                    didDiscoverCallBack?(peripheral, advertisementData, RSSI)
                    break
                }

            }
        }
        /*
        if let peripheralUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            print("\nDiscovered Services")
            
            for uuid in peripheralUUIDs {
                print("        -  \(uuid.uuidString)")
                
                connectedCharacteristics[peripheral] = [CBCharacteristic]()
                centralManager.connect(peripheral, options: nil)
                didDiscoverCallBack?(peripheral, advertisementData, RSSI)
                break
            }
        }
        */
        didDiscoverCallBack?(peripheral, advertisementData, RSSI)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("\nConnected to \(peripheral.name)")
        
        connectedCharacteristics[peripheral] = [CBCharacteristic]()
        
        let registeredServicesUUIDs = services.map { $0.uuid }
        
        peripheral.delegate = self
        peripheral.discoverServices(registeredServicesUUIDs)
        
        stopScan()
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to Connect to \(peripheral.name) - \(error)")
        connectedCharacteristics[peripheral] = nil
        peripheralConnectionCallback?(false, peripheral, error)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("didDisconnectPeripheral \(peripheral.name) - \(error)")
        connectedCharacteristics[peripheral] = nil
        peripheralConnectionCallback?(false, peripheral, error)
    }
}

extension EBCentralManager: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        guard let services = peripheral.services else {
            return
        }
        
        print("\nDiscovered Services:")
        
        for service in services {
            print("        - ", service.uuid.uuidString)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let services = peripheral.services else {
            return
        }
        
        print("\nDiscovered Service:")
        
        for service in services {
            print("        - ", service.uuid.uuidString)
            
            guard let characteristics = service.characteristics else {
                return
            }
            
            print("           - Characteristics:")
            
            for characteristic in characteristics {
                print("                - ", characteristic.uuid.uuidString)
                
                connectedCharacteristics[peripheral]!.append(characteristic)
                
                if characteristic.uuid.uuidString == mtuCharacteristicUUIDKey {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
            
            
            peripheralConnectionCallback?(true, peripheral, nil)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if characteristic.uuid.uuidString == mtuCharacteristicUUIDKey {
            var num: UInt8 = 0
            characteristic.value?.copyBytes(to: &num, count: MemoryLayout<Int>.size)
            
            mtuValue = Int16(num)
            peripheralConnectionCallback?(true, peripheral, nil)
        } else {
            
            guard let services = peripheral.services else {
                return
            }
            
            for service in services {
                
                guard let characteristics = service.characteristics,
                    let index = characteristics.index(of : characteristic),
                    let data = characteristics[index].value else {
                        return
                }
                
                guard let transactions = activeReadTransations[peripheral],
                    let transaction = transactions.first(where: { $0.characteristic == characteristic }) else {
                        return
                }
                
                transaction.responseCount = data.totalPackets
                transaction.chunks.append(data)
                transaction.completion?(data, nil)
                
             ///   read(fromUUID : characteristic.uuid.uuidString)
            }

            
         //   handleReadTransation(forCharacteristic : characteristic, from : peripheral)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        handleWriteTransationResponse(forCharacteristic : characteristic, from : peripheral)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        print("didDiscoverIncludedServicesFor ", peripheral, service)
    }
    
    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        print("peripheralDidUpdateName ", peripheral)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("didModifyServices ", peripheral)
    }
    
    public func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
        print("peripheralDidUpdateRSSI ", peripheral)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        print("didReadRSSI ", peripheral)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let notificationState  = characteristic.isNotifying ? "Registered" : "Unregistered"
        print("\n\(notificationState) Notification for characteristic\n        -  \(characteristic.uuid)\n")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("didDiscoverDescriptorsFor uuid: \(characteristic.uuid), value: \(characteristic.value)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        print("didUpdateValueFor uuid: \(descriptor.uuid), value: \(descriptor.value)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        print("didWriteValueFor descriptor uuid: \(descriptor.uuid), value: \(descriptor.value)")
    }
}
