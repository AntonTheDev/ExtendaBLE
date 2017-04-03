//
//  EBCentralManager.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth


public class EBCentralManager : NSObject {
    
    internal var centralManager : CBCentralManager
    internal var peripheralName : String?
    internal var mtuValue : Int16 = 23
    
    #if os(OSX)
    internal var _isScanning : Bool = false
    #endif
    
    internal var registeredServiceUUIDs = [CBUUID]()
    internal var chunkedCharacteristicUUIDS = [CBUUID]()
    internal var registeredCharacteristicUpdateCallbacks  = [CBUUID : EBTransactionCallback]()
    
    internal var connectedCharacteristics = [CBPeripheral : [CBCharacteristic]]()
    
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
    
    #if os(OSX)
    public var isScanning: Bool {
    get { return _isScanning }
    }
    #else
    public var isScanning: Bool {
        get { return centralManager.isScanning }
    }
    #endif
    
    @discardableResult public func startScan(allowDuplicates : Bool = true) ->  EBCentralManager {
        if centralManager.state != .poweredOn {
            return self
        }
        
        centralManager.scanForPeripherals(withServices: registeredServiceUUIDs, options: nil)
        
        return self
    }
    
    @discardableResult public func stopScan() -> EBCentralManager {
        centralManager.stopScan()
        #if os(OSX)
            _isScanning = false
        #endif
        return self
    }
    
    public func write(data : Data, toUUID uuid: String, completion : EBTransactionCallback? = nil) {
        
        for (peripheral, characteristics) in connectedCharacteristics {
            
            if let characteristic = characteristics.first(where: { $0.uuid.uuidString == uuid }) {
                
                var transactionType : TransactionType = .write
                
                if let _  = chunkedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
                    transactionType = .writeChunkable
                }
                
                let transaction = Transaction(transactionType, .centralToPeripheral, mtuSize : mtuValue)
                
                transaction.data = data
                transaction.characteristic = characteristic
                transaction.completion = completion
                
                if activeWriteTransations[peripheral] == nil {
                    activeWriteTransations[peripheral] = [transaction]
                } else {
                    activeWriteTransations[peripheral]!.append(transaction)
                }
                
                for packet in transaction.dataPackets {
                    peripheral.writeValue(packet, for: characteristic, type: .withResponse)
                }
            }
        }
    }
    
    func handleWriteTransationResponse(forCharacteristic characteristic: CBCharacteristic, from peripheral: CBPeripheral) {
        
        guard let transactions = activeWriteTransations[peripheral],
            let transaction = transactions.first(where: { $0.characteristic == characteristic }) else {
                return
        }
        
        transaction.receivedReceipt()
        
        if transaction.isComplete {
            transaction.completion?(transaction.data!, nil)
            activeWriteTransations[peripheral] = nil
        }
    }
    
    public func read(fromUUID uuid: String, completion : EBTransactionCallback? = nil) {
        
        for (peripheral, _) in connectedCharacteristics {
            
            if let characteristic = connectedCharacteristics[peripheral]?.first(where: { $0.uuid.uuidString == uuid }) {
                
                if activeReadTransations[peripheral]?.first(where: { $0.characteristic == characteristic }) == nil {
                    
                    if activeReadTransations[peripheral] == nil {
                        activeReadTransations[peripheral] = [Transaction]()
                    }
                    var transactionType : TransactionType = .read
                    
                    if let _  = chunkedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
                        transactionType = .readChunkable
                    }
                    
                    let transaction = Transaction(transactionType, .centralToPeripheral)
                    transaction.characteristic = characteristic
                    transaction.completion = completion
                    
                    activeReadTransations[peripheral]!.append(transaction)
                }
            }
            
            if let characteristic = connectedCharacteristics[peripheral]?.first(where: { $0.uuid.uuidString == uuid }) {
                peripheral.readValue(for: characteristic)
                return
            }
        }
    }
    
    internal func handleReadResponseTransation(forCharacteristic characteristic: CBCharacteristic, from peripheral: CBPeripheral) {
        
        guard let transactions = activeReadTransations[peripheral],
            let transaction = transactions.first(where: { $0.characteristic == characteristic }) else {
                return
        }
        
        transaction.appendPacket(characteristic.value)
        transaction.receivedReceipt()
        
        if transaction.isComplete {
            transaction.completion?(transaction.data!, nil)
            activeReadTransations[peripheral] = nil
        } else {
            read(fromUUID : characteristic.uuid.uuidString)
        }
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
        if #available(iOS 10.0, *) {
            switch central.state{
            case .poweredOn:
                startScan()
            default:
                break
            }
            
            print("\nCentral BLE state - \(central.state.rawValue)")
            stateChangeCallBack?(EBManagerState(rawValue: central.state.rawValue)!)
        } else {
            switch central.state{
            case .poweredOn:
                startScan()
            default:
                break
            }
            
            print("\nCentral BLE state - \(central.state.rawValue)")
            stateChangeCallBack?(EBManagerState(rawValue: central.state.rawValue)!)
        }
    }

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String : Any],
                               rssi RSSI: NSNumber) {
        
        if let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool, isConnectable == true {
            
            if let localname = advertisementData[CBAdvertisementDataLocalNameKey] as? String, localname == peripheralName {
                print("\nDiscovered Services By Local Name")
                connectedCharacteristics[peripheral] = [CBCharacteristic]()
                centralManager.connect(peripheral, options: nil)
                didDiscoverCallBack?(peripheral, advertisementData, RSSI)
                return
            } else if let peripheralUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                
                for uuid in registeredServiceUUIDs {
                    if let _ = peripheralUUIDs.first(where: { $0 == uuid })  {
                        
                        print("\n Discovered BY UUID -  \(uuid.uuidString)")
                        
                        connectedCharacteristics[peripheral] = [CBCharacteristic]()
                        centralManager.connect(peripheral, options: nil)
                        didDiscoverCallBack?(peripheral, advertisementData, RSSI)
                        return
                    }
                }
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("\nConnected to \(String(describing: peripheral.name))")
        
        connectedCharacteristics[peripheral] = [CBCharacteristic]()
        
        peripheral.delegate = self
        peripheral.discoverServices(registeredServiceUUIDs)
        
        stopScan()
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to Connect to \(String(describing: peripheral.name)) - \(String(describing: error))")
        connectedCharacteristics[peripheral] = nil
        peripheralConnectionCallback?(false, peripheral, error)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("didDisconnectPeripheral \(String(describing: peripheral.name)) - \(String(describing: error))")
        connectedCharacteristics[peripheral] = nil
        peripheralConnectionCallback?(false, peripheral, error)
    }
}

extension EBCentralManager: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        guard let services = peripheral.services else {
            return
        }
        
        print("\nDiscovered Services: \(services)")
        
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
            
            if chunkedCharacteristicUUIDS.count == 0 {
                peripheralConnectionCallback?(true, peripheral, nil)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if characteristic.uuid.uuidString == mtuCharacteristicUUIDKey &&
            chunkedCharacteristicUUIDS.count > 0 {
            
            var num: UInt8 = 0
            characteristic.value?.copyBytes(to: &num, count: MemoryLayout<Int>.size)
            
            mtuValue = Int16(num)
            peripheralConnectionCallback?(true, peripheral, nil)
        } else {
            handleReadResponseTransation(forCharacteristic : characteristic, from : peripheral)
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
        print("didDiscoverDescriptorsFor uuid: \(characteristic.uuid), value: \(String(describing: characteristic.value))")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        print("didUpdateValueFor uuid: \(descriptor.uuid), value: \(String(describing: descriptor.value))")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        print("didWriteValueFor descriptor uuid: \(descriptor.uuid), value: \(String(describing: descriptor.value))")
    }
}
