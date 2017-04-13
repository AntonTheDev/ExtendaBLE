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
    
    internal var centralManager : CBCentralManager!
    internal var peripheralName : String?
    
    #if os(OSX)
    internal var _isScanning : Bool                 = false
    #endif
    
    internal var registeredServiceUUIDs             = [CBUUID]()
    internal var chunkedCharacteristicUUIDS         = [CBUUID]()
    internal var registeredCharacteristicCallbacks  = [CBUUID : EBTransactionCallback]()
    
    internal var connectedCharacteristics           = [CBPeripheral : [CBCharacteristic]]()
    internal var peripheralMTUValues                = [CBPeripheral : Int16]()
    
    internal var activeWriteTransations             = [CBPeripheral : [Transaction]]()
    internal var activeReadTransations              = [CBPeripheral : [Transaction]]()
    
    internal var operationQueue                     = DispatchQueue(label: "CentralManagerQueue", qos: .default)
    internal var dataQueue                          = DispatchQueue(label: "CentralManagerOperationQueue", qos: .userInitiated)
    
    internal var defaultPeripheralCacheKey          = "EBCentralManagerDefaultPeripheralCacheKey"
    internal var peripheralCacheKey : String!
    
    internal var stateChangeCallBack          : CentralManagerStateChangeCallback?
    internal var didDiscoverCallBack          : CentralManagerDidDiscoverCallback?
    internal var peripheralConnectionCallback : CentralManagerPeripheralConnectionCallback?
    
    internal var scanningRequested : Bool = false
    
    public required init(queue: DispatchQueue? = nil,  options: [String : Any]? = nil, peripheralCacheKey key: String? = nil) {
        super.init()
        
        if let key = key {
            self.peripheralCacheKey = key
        } else {
            self.peripheralCacheKey = defaultPeripheralCacheKey
        }
        
        centralManager = CBCentralManager(delegate: self, queue:  (queue == nil ? queue : operationQueue), options: options)
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
    
    @discardableResult public func startScan(allowDuplicates : Bool = false) ->  EBCentralManager {
        if centralManager.state != .poweredOn {
            return self
        }
        
        retrieveAndScanIfNeeded()
        return self
    }
    
    @discardableResult public func stopScan() -> EBCentralManager {
        centralManager.stopScan()
        #if os(OSX)
            _isScanning = false
        #endif
        return self
    }
    
    func retrieveAndScanIfNeeded() {
        
        if let cachedPeripherals = cachedPeripherals() {
            for peripheral in cachedPeripherals {
                Log(.debug, logString: "Central Found Cached Peripheral \(String(describing: peripheral.name)), Attempting to Connect")
                connectedCharacteristics[peripheral] = [CBCharacteristic]()
                centralManager.connect(peripheral, options: nil)
                
                operationQueue.asyncAfter(deadline: .now() + 3.0, execute: { [unowned self] in
                    if peripheral.state != .connected {
                        Log(.debug, logString: "Failed to Reconnect To \(String(describing: peripheral.name)), Attempting to Scan")
                        
                        self.deleteConnected(peripheral)
                        self.centralManager.scanForPeripherals(withServices: self.registeredServiceUUIDs, options: nil)
                    }
                })
            }
        } else {
            Log(.debug, logString: "Central Started Scanning For Services")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
        
        #if os(OSX)
            _isScanning = true
        #endif
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
        operationQueue.async { [unowned self] in
            self.handleStateChange(central)
        }
    }
    
    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String : Any],
                               rssi RSSI: NSNumber) {
        operationQueue.async { [unowned self] in
            self.handleDiscoveryEvent(didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        operationQueue.async { [unowned self] in
            self.saveConnected(peripheral)
            self.handleConnectTo(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        operationQueue.async { [unowned self] in
            self.disconnect(peripheral, error)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        operationQueue.async { [unowned self] in
            self.disconnect(peripheral, error)
        }
    }
    
    #if os(iOS) || os(tvOS)
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    
    }
    #endif
    
    internal func handleStateChange(_ central: CBCentralManager) {
        
        switch central.state {
        case .poweredOn:
            operationQueue.async { [unowned self] in
                self.retrieveAndScanIfNeeded()
            }
        default:
            break
        }
        
        Log(.debug, logString: "Central BLE state - \(central.state.rawValue)")
        
        stateChangeCallBack?(EBManagerState(rawValue: central.state.rawValue)!)
    }
    
    internal func handleDiscoveryEvent(didDiscover peripheral: CBPeripheral,
                                       advertisementData: [String : Any],
                                       rssi RSSI: NSNumber) {
        
        if peripheral.state == .connected {
            return
        }
        if let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool, isConnectable == true {
            if let localname = advertisementData[CBAdvertisementDataLocalNameKey] as? String, localname == peripheralName {
                connect(peripheral, advertisementData, RSSI)
                stopScan()
                return
            }
            else if let peripheralUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                
                let upperCasedServiceIDS = peripheralUUIDs.map { $0.uuidString.uppercased()}
                let upperCasedRegisteredIDS = registeredServiceUUIDs.map { $0.uuidString.uppercased()}
                
                for uuid in upperCasedRegisteredIDS {
                    if let _ = upperCasedServiceIDS.first(where: { $0 == uuid })  {
                        connect(peripheral, advertisementData, RSSI)
                        stopScan()
                        return
                    }
                }
            }
        }
    }
    
    private func connect(_ peripheral : CBPeripheral,
                         _ advertisementData: [String : Any],
                         _ RSSI: NSNumber) {
        
        if connectedCharacteristics.keys.contains(peripheral) {
            return
        }
        
        Log(.debug, logString: "Discovered Peripheral / Connecting to \(String(describing: peripheral.name))")
        
        connectedCharacteristics[peripheral] = [CBCharacteristic]()
        centralManager.connect(peripheral, options: nil)
        didDiscoverCallBack?(peripheral, advertisementData, RSSI)
    }
    
    internal func handleConnectTo(_ peripheral: CBPeripheral) {
        
        if peripheral.state != .connected {
            return
        }
        
        Log(.debug, logString: "Connected to \(String(describing: peripheral.name))")
        
        if connectedCharacteristics[peripheral]?.count == 0 {
            peripheral.delegate = self
            peripheral.discoverServices(registeredServiceUUIDs)
        }
    }
    
    func disconnect(_ peripheral : CBPeripheral, _ error: Error?) {
        
        Log(.debug, logString: "Disconnect from \(String(describing: peripheral.name)) - \(String(describing: error))")
        
        activeWriteTransations[peripheral] = nil
        activeReadTransations[peripheral] = nil
        peripheralMTUValues[peripheral] = nil
        connectedCharacteristics[peripheral] = nil
        
        deleteConnected(peripheral)
        
        if peripheral.state != .connected {
            return
        }
        
        for (peripheral, characteristics) in connectedCharacteristics {
            
            for characteristic in characteristics {
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(false, for: characteristic)
                }
            }
        }
        
        centralManager.cancelPeripheralConnection(peripheral)
        peripheralConnectionCallback?(false, peripheral, error)
    }
}

extension EBCentralManager: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        operationQueue.async { [unowned self] in
            self.handleServicesDiscovered(for : peripheral, error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        operationQueue.async { [unowned self] in
            self.handleCharacteristicsDiscovered(for : service, on : peripheral, error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        dataQueue.async { [unowned self] in
            self.handleReadTransationResponse(forCharacteristic: characteristic, from: peripheral, error: error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        dataQueue.async { [unowned self] in
            self.handleWriteTransationResponse(forCharacteristic : characteristic, from : peripheral)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        dataQueue.async { [unowned self] in
            self.handleNotificationStateUpdate(peripheral, characteristic, error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        Log(.debug, logString: "didDiscoverIncludedServicesFor \(peripheral) \(service)")
    }
    
    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        Log(.debug, logString: "peripheralDidUpdateName \(peripheral)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        Log(.debug, logString: "didModifyServices \(peripheral)")
    }
    
    public func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
        Log(.debug, logString: "peripheralDidUpdateRSSI \(peripheral)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        Log(.debug, logString: "didReadRSSI \(peripheral)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        Log(.debug, logString: "didDiscoverDescriptorsFor uuid: \(characteristic.uuid), value: \(String(describing: characteristic.value))")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        Log(.debug, logString: "didUpdateValueFor uuid: \(descriptor.uuid), value: \(String(describing: descriptor.value))")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        Log(.debug, logString: "didWriteValueFor descriptor uuid: \(descriptor.uuid), value: \(String(describing: descriptor.value))")
    }
    
    internal func handleServicesDiscovered(for peripheral : CBPeripheral, _ error : Error?) {
        
        guard let services = peripheral.services else {
            return
        }
        
        Log(.debug, logString: "Discovered Services: \(services)")
        
        for service in services {
            Log(.debug, logString: "        - \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    internal func handleCharacteristicsDiscovered(for service: CBService, on peripheral: CBPeripheral, _ error: Error?) {
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        Log(.debug, logString: "Service: \(service.uuid.uuidString)")
        Log(.debug, logString: "          - Characteristics:")
        
        for characteristic in characteristics {
            Log(.debug, logString: "             - \(characteristic.uuid.uuidString)")
            
            if !(connectedCharacteristics[peripheral]?.contains(characteristic))! {
                connectedCharacteristics[peripheral]!.append(characteristic)
                
                if characteristic.uuid.uuidString.uppercased() == mtuCharacteristicUUIDKey {
                    if characteristic.properties.contains(.notify) {
                        Log(.debug, logString: "Triggered Notification Registration for: \(characteristic.uuid.uuidString)")
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                }
            }
        }
        
        if chunkedCharacteristicUUIDS.count == 0 {
            peripheralConnectionCallback?(true, peripheral, nil)
        }
    }
    
    internal func handleNotificationStateUpdate(_ peripheral: CBPeripheral, _ characteristic: CBCharacteristic, _ error: Error?) {
        let notificationState  = characteristic.isNotifying ? "Registered" : "Unregistered"
        Log(.debug, logString: "\(notificationState) Notification for characteristic")
        Log(.debug, logString: "        -  \(characteristic.uuid)")
    }
}

extension EBCentralManager {
    
    public func write(data : Data, toUUID uuid: String, completion : EBTransactionCallback? = nil) {
        
        dataQueue.async { [unowned self] in
            for (peripheral, _) in self.connectedCharacteristics {
                
                if let characteristic = self.characteristic(for: uuid, on: peripheral) {
                    
                    guard let transaction = self.writeTransaction(for : characteristic,
                                                                  to  : peripheral) else {
                                                                    return
                    }
                    
                    transaction.data = data
                    if completion != nil { transaction.completion = completion }
                    
                    for packet in transaction.dataPackets {
                        peripheral.writeValue(packet, for: characteristic, type: .withResponse)
                    }
                }
            }
        }
    }
    
    public func read(fromUUID uuid: String, completion : EBTransactionCallback? = nil) {
        dataQueue.async { [unowned self] in
            for (peripheral, _) in self.connectedCharacteristics {
                
                if let characteristic = self.characteristic(for: uuid, on: peripheral) {
                    
                    guard let transaction = self.readTransaction(for : characteristic,
                                                                 from : peripheral) else {
                                                                    return
                    }
                    
                    if completion != nil { transaction.completion = completion }
                    
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }
}
extension EBCentralManager {
    
    internal func handleWriteTransationResponse(forCharacteristic characteristic: CBCharacteristic, from peripheral: CBPeripheral) {
        
        guard let transaction = writeTransaction(for : characteristic, to  : peripheral) else {
            return
        }
        
        transaction.processTransaction()
        
        Log(.debug, logString: "Central Send Write Packet  \(transaction.activeResponseCount)  / \(transaction.totalPackets)")
        
        if transaction.isComplete {
            Log(.debug, logString: "Central Write Compelete")
            transaction.completion?(transaction.data!, nil)
            clearWriteTransaction(from: peripheral, on: characteristic)
        }
    }
    
    internal func handleReadTransationResponse(forCharacteristic characteristic: CBCharacteristic, from peripheral: CBPeripheral, error: Error?) {
        
        if characteristic.uuid.uuidString == mtuCharacteristicUUIDKey &&
            chunkedCharacteristicUUIDS.count > 0 {
            handleMTUValueUpdate(for: characteristic, on: peripheral)
            return
        }
        
        guard let transaction = readTransaction(for: characteristic, from: peripheral) else {
            return
        }
        
        transaction.appendPacket(characteristic.value)
        transaction.processTransaction()
        
        Log(.debug, logString: "Central Received Read Packet  \(transaction.activeResponseCount)  / \(transaction.totalPackets)")
        
        if transaction.isComplete {
            Log(.debug, logString: "Central Read Compelete")
            
            transaction.completion?(transaction.data!, nil)
            clearReadTransaction(from: peripheral, on: characteristic)
        } else {
            read(fromUUID : characteristic.uuid.uuidString)
        }
    }
    
    internal func handleMTUValueUpdate(for characteristic : CBCharacteristic, on peripheral : CBPeripheral) {
        
        guard let value =  characteristic.value?.int16Value(inRange: 0..<2) else {
            return
        }
        
        Log(.debug, logString: "Received MTU \(value)\n");
        
        peripheralMTUValues[peripheral] = value
        peripheralConnectionCallback?(true, peripheral, nil)
        
    }
}

extension EBCentralManager {
    
    internal func writeTransaction(for characteristic : CBCharacteristic,
                                   to peripheral : CBPeripheral) -> Transaction? {
        
        var activeWriteTransation = activeWriteTransations[peripheral]?.first(where: { $0.characteristic?.uuid == characteristic.uuid })
        
        if activeWriteTransation != nil  {
            return activeWriteTransation
        }
        
        if activeWriteTransations[peripheral] == nil {
            activeWriteTransations[peripheral] = [Transaction]()
        }
        
        var transactionType : TransactionType = .write
        
        if let _  = chunkedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .writeChunkable
        }
        
        guard let mtuValue = self.peripheralMTUValues[peripheral] else {
            Log(.debug, logString: "Central to Peripheral MTU Value Not Found")
            return nil
        }
        
        activeWriteTransation = Transaction(transactionType,
                                            .centralToPeripheral,
                                            characteristic : characteristic,
                                            mtuSize : mtuValue)
        
        activeWriteTransations[peripheral]!.append(activeWriteTransation!)
        
        return activeWriteTransation
    }
    
    internal func readTransaction(for characteristic : CBCharacteristic,
                                  from peripheral : CBPeripheral) -> Transaction? {
        
        
        var activeReadTransation = activeReadTransations[peripheral]?.first(where: { $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        
        if activeReadTransation != nil  {
            return activeReadTransation
        }
        
        if self.activeReadTransations[peripheral] == nil {
            self.activeReadTransations[peripheral] = [Transaction]()
        }
        
        var transactionType : TransactionType = .read
        
        if let _  = self.chunkedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .readChunkable
        }
        
        activeReadTransation = Transaction(transactionType, .centralToPeripheral,
                                           characteristic : characteristic)
        
        self.activeReadTransations[peripheral]!.append(activeReadTransation!)
        
        return activeReadTransation
    }
    
    internal func characteristic(for uuid: String, on peripheral : CBPeripheral) -> CBCharacteristic? {
        
        if let characteristic = self.connectedCharacteristics[peripheral]?.first(where:
            { $0.uuid.uuidString.uppercased() == uuid.uppercased() })
        {
            return characteristic
        }
        
        return nil
    }
    
    internal func clearReadTransaction(from peripheral: CBPeripheral, on characteristic : CBCharacteristic) {
        if let index = self.activeReadTransations[peripheral]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeReadTransations[peripheral]?.remove(at: index)
        }
    }
    
    internal func clearWriteTransaction(from peripheral: CBPeripheral, on characteristic : CBCharacteristic) {
        if let index = self.activeWriteTransations[peripheral]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeWriteTransations[peripheral]?.remove(at: index)
        }
    }
}

extension EBCentralManager {
    
    internal func saveConnected(_ peripheral : CBPeripheral) {
        if var uuids = UserDefaults.standard.array(forKey: peripheralCacheKey) as? [String] {
            if !uuids.contains(peripheral.identifier.uuidString) {
                uuids.append(peripheral.identifier.uuidString)
                
                UserDefaults.standard.set(uuids, forKey : peripheralCacheKey)
                UserDefaults.standard.synchronize()
            }
        } else {
            UserDefaults.standard.set([peripheral.identifier.uuidString], forKey : peripheralCacheKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    internal func deleteConnected(_ peripheral : CBPeripheral) {
        if var uuids = UserDefaults.standard.array(forKey: peripheralCacheKey) as? [String] {
            
            if let index = uuids.index(of: peripheral.identifier.uuidString) {
                uuids.remove(at: index)
            }
            
            UserDefaults.standard.set(uuids, forKey : peripheralCacheKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    internal func cachedPeripherals() -> [CBPeripheral]? {
        
        guard let uuids = UserDefaults.standard.array(forKey: self.peripheralCacheKey) as? [String],
            let uuidArray = uuids.map({ UUID(uuidString: $0) }) as? [UUID] else {
                return nil
        }
        
        let peripherals = centralManager.retrievePeripherals(withIdentifiers:uuidArray)
        
        guard peripherals.count != 0 else {
            return nil
        }
        
        for peripheral in peripherals {
            connectedCharacteristics[peripheral] = [CBCharacteristic]()
        }
        
        return peripherals
    }
}
