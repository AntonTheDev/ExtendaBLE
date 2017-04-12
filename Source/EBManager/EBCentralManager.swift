//
//  EBCentralManager.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public class EBCentralManager : NSObject {
    
    internal var centralManager : CBCentralManager
    internal var peripheralName : String?
    
    #if os(OSX)
    internal var _isScanning : Bool = false
    #endif
    
    internal var registeredServiceUUIDs = [CBUUID]()
    internal var chunkedCharacteristicUUIDS = [CBUUID]()
    internal var registeredCharacteristicUpdateCallbacks  = [CBUUID : EBTransactionCallback]()
    
    internal var connectedCharacteristics = [CBPeripheral : [CBCharacteristic]]()
    internal var peripheralMTUValues = [CBPeripheral : Int16]()
    
    internal var activeWriteTransations = [CBPeripheral : [Transaction]]()
    internal var activeReadTransations  = [CBPeripheral : [Transaction]]()
    
    internal var stateChangeCallBack          : CentralManagerStateChangeCallback?
    internal var didDiscoverCallBack          : CentralManagerDidDiscoverCallback?
    internal var peripheralConnectionCallback : CentralManagerPeripheralConnectionCallback?
    
    internal var defaultQueue = DispatchQueue(label: "CentralManagerQueue", qos: .default)
    internal var dataQueue = DispatchQueue(label: "DataOperationQueue", qos: .userInitiated)
    
    public required init(queue: DispatchQueue? = nil,  options: [String : Any]? = nil) {
        centralManager = CBCentralManager(delegate: nil, queue: (queue == nil ? queue : defaultQueue), options: options)
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
        
        #if os(OSX)
            _isScanning = true
        #endif
        
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
        dataQueue.async { [unowned self] in
            
            for (peripheral, characteristics) in self.connectedCharacteristics {
                
                if let characteristic = characteristics.first(where: { $0.uuid.uuidString == uuid }) {
                    
                    var transactionType : TransactionType = .write
                    
                    if let _  = self.chunkedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
                        transactionType = .writeChunkable
                    }
                    
                    guard let mtuValue = self.peripheralMTUValues[peripheral] else {
                        print("Central to Peripheral MTU Value Not Found")
                        return
                    }
                    
                    let transaction = Transaction(transactionType, .centralToPeripheral, mtuSize : mtuValue)
                    
                    transaction.data = data
                    transaction.characteristic = characteristic
                    transaction.completion = completion
                    
                    if self.activeWriteTransations[peripheral] == nil {
                        self.activeWriteTransations[peripheral] = [transaction]
                    } else {
                        self.activeWriteTransations[peripheral]!.append(transaction)
                    }
                    
                    for packet in transaction.dataPackets {
                        peripheral.writeValue(packet, for: characteristic, type: .withResponse)
                    }
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
        
        print("Central Send Write Packet ", transaction.activeResponseCount, " / ",  transaction.totalPackets)
        
        if transaction.isComplete {
            transaction.completion?(transaction.data!, nil)
            activeWriteTransations[peripheral] = nil
        }
    }
    
    public func read(fromUUID uuid: String, completion : EBTransactionCallback? = nil) {
        
        dataQueue.async { [unowned self] in
            
            for (peripheral, _) in self.connectedCharacteristics {
                
                if let characteristic = self.connectedCharacteristics[peripheral]?.first(where: { $0.uuid.uuidString == uuid }) {
                    
                    if self.activeReadTransations[peripheral]?.first(where: { $0.characteristic == characteristic }) == nil {
                        
                        if self.activeReadTransations[peripheral] == nil {
                            self.activeReadTransations[peripheral] = [Transaction]()
                        }
                        var transactionType : TransactionType = .read
                        
                        if let _  = self.chunkedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
                            transactionType = .readChunkable
                        }
                        
                        let transaction = Transaction(transactionType, .centralToPeripheral)
                        transaction.characteristic = characteristic
                        transaction.completion = completion
                        
                        self.activeReadTransations[peripheral]!.append(transaction)
                    }
                    
                    peripheral.readValue(for: characteristic)
                }
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
        print("Central Received Read Packet ", transaction.activeResponseCount, " / ",  transaction.totalPackets)
        
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
        switch central.state{
        case .poweredOn:
            startScan()
        default:
            break
        }
        
        print("\nCentral BLE state - \(central.state.rawValue)")
        stateChangeCallBack?(EBManagerState(rawValue: central.state.rawValue)!)
    }
    
    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String : Any],
                               rssi RSSI: NSNumber) {
        
        if let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool, isConnectable == true {
            if let localname = advertisementData[CBAdvertisementDataLocalNameKey] as? String, localname == peripheralName {
                print("\nDiscovered Services By Local Name")
                
                connectTo(peripheral)
                didDiscoverCallBack?(peripheral, advertisementData, RSSI)
                return
            } else if let peripheralUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                
                for uuid in registeredServiceUUIDs {
                    if let _ = peripheralUUIDs.first(where: { $0 == uuid })  {
                        print("\nDiscovered UUID -  \(uuid.uuidString)")
                        
                        connectTo(peripheral)
                        didDiscoverCallBack?(peripheral, advertisementData, RSSI)
                        return
                    }
                }
            }
        }
    }
    
    private func connectTo(_ peripheral : CBPeripheral) {
        if connectedCharacteristics.keys.contains(peripheral) {
            return
        }
        
        connectedCharacteristics[peripheral] = [CBCharacteristic]()
        centralManager.connect(peripheral, options: nil)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        print("\nConnected to \(String(describing: peripheral.name))")
        
        if connectedCharacteristics[peripheral]?.count == 0 {
            peripheral.delegate = self
            peripheral.discoverServices(registeredServiceUUIDs)
        }
        
        if chunkedCharacteristicUUIDS.count == 0 {
            peripheralConnectionCallback?(true, peripheral, nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to Connect to \(String(describing: peripheral.name)) - \(String(describing: error))")
        flushPeripheral(peripheral, error)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("didDisconnectPeripheral \(String(describing: peripheral.name)) - \(String(describing: error))")
        flushPeripheral(peripheral, error)
    }
    
    private func flushPeripheral(_ peripheral : CBPeripheral, _ error: Error?) {
        connectedCharacteristics[peripheral] = nil
        activeWriteTransations[peripheral] = nil
        activeReadTransations[peripheral] = nil
        peripheralMTUValues[peripheral] = nil
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
        
        print("\nService:", service.uuid.uuidString)
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("          - Characteristics:")
        
        for characteristic in characteristics {
            print("             -", characteristic.uuid.uuidString)
            if !(connectedCharacteristics[peripheral]?.contains(characteristic))! {
                connectedCharacteristics[peripheral]!.append(characteristic)
                if characteristic.uuid.uuidString == mtuCharacteristicUUIDKey {
                    print("Register")
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
        
        if chunkedCharacteristicUUIDS.count == 0 {
            peripheralConnectionCallback?(true, peripheral, nil)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if characteristic.uuid.uuidString == mtuCharacteristicUUIDKey &&
            chunkedCharacteristicUUIDS.count > 0 {
            dataQueue.async { [unowned self] in
                guard let value =  characteristic.value?.int16Value(0..<2) else {
                    return
                }
                
                print("Received MTU ", value, "\n");
                
                self.peripheralMTUValues[peripheral] = value
                self.peripheralConnectionCallback?(true, peripheral, nil)
            }
        } else {
            dataQueue.async { [unowned self] in
                self.handleReadResponseTransation(forCharacteristic : characteristic, from : peripheral)
            }
            
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        dataQueue.async { [unowned self] in
            self.handleWriteTransationResponse(forCharacteristic : characteristic, from : peripheral)
        }
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
