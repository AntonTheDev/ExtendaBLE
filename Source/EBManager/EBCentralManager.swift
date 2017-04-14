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
    
    internal var centralManager             : CBCentralManager!
    
    // The peripheral name to search for, the central will attempt to connect if defined
    // otherwise it will scan for registered services defined during constructions only
    internal var peripheralName             : String?
    internal var supportMutiplePeripherals  = false
    
    // Reconnect on start stores devices we haev connected to prior
    internal var reconnectOnStart           = true
    internal var reconnectCacheKey          = "EBCentralManagerDefaultPeripheralCacheKey"
    internal var reconnectTimeout           = 2.0
    
    // If no devices are found it will rescan after the internal specified, defailt is 0
    // which implies that it will not rescan automatically
    // The scan time out will stop scanning after 10 seconds, and restart it after the rescanInterval
    internal var rescanInterval             = 0.0
    internal var rescanTimer : Timer?
    internal var scanTimeout                = 10.0
    
    // Options defined during creation
    internal var scanOptions                = [String : Any]()
    internal var connectionOptions          = [String : Any]()
    
    // Services Defined during creation
    internal var registeredServiceUUIDs             = [CBUUID]()
    internal var chunkedCharacteristicUUIDS         = [CBUUID]()
    internal var registeredCharacteristicCallbacks  = [CBUUID : EBTransactionCallback]()
    
    // TODO: Make sure to remove the peripheral on disconnect and set the delegate to nill
    internal var connectedPeripherals               = [CBPeripheral]()
    
    internal var peripheralCharacteristics          = [UUID : [CBCharacteristic]]()
    internal var peripheralMTUValues                = [UUID : Int16]()
    
    internal var activeWriteTransations             = [UUID : [Transaction]]()
    internal var activeReadTransations              = [UUID : [Transaction]]()
    
    internal var operationQueue                     = DispatchQueue(label: "CentralManagerQueue", qos: .userInitiated)
    internal var dataQueue                          = DispatchQueue(label: "CentralManagerOperationQueue", qos: .userInitiated)
    
    internal var stateChangeCallBack                : CentralManagerStateChangeCallback?
    internal var didDiscoverCallBack                : CentralManagerDidDiscoverCallback?
    internal var peripheralConnectionCallback       : CentralManagerPeripheralConnectionCallback?
    
    internal var scanningRequested  = false
    
    #if os(OSX)
    internal var _isScanning        = false
    #endif
    
    public required init(queue: DispatchQueue? = nil, options: [String : Any]? = nil, scanOptions : [String : Any]? = nil) {
        super.init()
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
    
    @discardableResult public func startScan() -> EBCentralManager {
        
        if centralManager.state != .poweredOn {
            return self
        }
        
        let triggerScan : (() -> ()) = { [unowned self] in
            
            Log(.debug, logString: "Started Scan")
            
            self.rescanTimer?.invalidate()
            self.centralManager.scanForPeripherals(withServices: self.registeredServiceUUIDs,
                                                   options: self.scanOptions)
            
            #if os(OSX)
                self._isScanning = true
            #endif
        }
        
        if reconnectOnStart == false {
            triggerScan()
            return self
        }
        
        guard let cachedPeripherals = cachedPeripherals() else {
            triggerScan()
            return self
        }
        
        for peripheral in cachedPeripherals {
            
            Log(.debug, logString: "Central Found Cached Peripheral \(String(describing: peripheral.name)), Attempting to Connect")
            
            connect(to: peripheral)
            
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + reconnectTimeout, execute: { [unowned self] in
                if peripheral.state != .connected {
                    Log(.debug, logString: "Failed to Reconnect To \(String(describing: peripheral.name)), Attempting to Scan")
                    self.unCachedPeripheral(peripheral.identifier)
                    triggerScan()
                }
            })
        }
        
        return self
    }
    
    @discardableResult public func stopScan() -> EBCentralManager {
        
        Log(.debug, logString: "Stopped Scan")
        centralManager.stopScan()
        
        if  supportMutiplePeripherals == false &&
            rescanInterval > 0 &&
            connectedPeripherals.count == 0
        {
            rescanTimer?.invalidate()
            
            rescanTimer =   Timer(fireAt: Date().addingTimeInterval(rescanInterval),
                                  interval: 0.0,
                                  target: self,
                                  selector: #selector(startScan),
                                  userInfo: nil,
                                  repeats: false)
            
        }
    
    #if os(OSX)
    _isScanning = false
    #endif
    
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
       // operationQueue.async { [unowned self] in
            self.handleDiscoveryEvent(didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
       // }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        operationQueue.async { [unowned self] in
            
            Log(.debug, logString: "Connected to \(String(describing: peripheral.name))")
            
            self.cachePeripheral(peripheral.identifier)
            
            peripheral.delegate = self
            peripheral.discoverServices(self.registeredServiceUUIDs)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        operationQueue.async { [unowned self] in
            self.disconnect(peripheral.identifier, error)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        operationQueue.async { [unowned self] in
            self.disconnect(peripheral.identifier, error)
        }
    }
    /*
    #if os(iOS) || os(tvOS)
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    
    }
    #endif
    */
    internal func handleStateChange(_ central: CBCentralManager) {
        Log(.debug, logString: "Central BLE state - \(central.state.rawValue)")
        
        
        switch central.state {
        case .poweredOn:
       //     operationQueue.async { [unowned self] in
                self.startScan()
       //     }
        default:
            break
        }
        
        stateChangeCallBack?(EBManagerState(rawValue: central.state.rawValue)!)
    }
    
    internal func handleDiscoveryEvent(didDiscover peripheral: CBPeripheral,
                                       advertisementData: [String : Any],
                                       rssi RSSI: NSNumber) {
        
        if peripheral.state == .connected {
            return
        }
        
        if shouldConnect(to : peripheral, with: advertisementData, RSSI) {
            connect(to : peripheral)
        }
    }
    
    func connect(to peripheral : CBPeripheral) {
        
        if peripheral.state == .connected {
            return
        }
        
        connectedPeripherals.append(peripheral)
        
        Log(.debug, logString: "Connecting to \(String(describing: peripheral.name))")
        
        peripheralCharacteristics[peripheral.identifier] = [CBCharacteristic]()
        centralManager.connect(peripheral, options: connectionOptions)
        
        if supportMutiplePeripherals == false {
            stopScan()
        }
    }
    
    private func shouldConnect(to peripheral : CBPeripheral,
                               with advertisementData: [String : Any],
                               _ RSSI: NSNumber) -> Bool {
        
        guard let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool, isConnectable else {
            return false
        }
        
        guard connectedPeripherals.contains(peripheral) == false else {
            return false
        }
        
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String, name == peripheralName {
            return true
        }
        
        if let peripheralUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            
            let upperCasedServiceIDS = peripheralUUIDs.map { $0.uuidString.uppercased()}
            let upperCasedRegisteredIDS = registeredServiceUUIDs.map { $0.uuidString.uppercased()}
            
            for uuid in upperCasedRegisteredIDS {
                if let _ = upperCasedServiceIDS.first(where: { $0 == uuid })  {
                    return true
                }
            }
        }
        
        return false
    }
    
    func disconnect(_ peripheralUUID : UUID, _ error: Error?) {
        
        Log(.debug, logString: "Disconnect from \(String(describing: peripheralUUID)) - \(String(describing: error))")
        
        activeWriteTransations[peripheralUUID]      = nil
        activeReadTransations[peripheralUUID]       = nil
        
        peripheralMTUValues[peripheralUUID]         = nil
        peripheralCharacteristics[peripheralUUID]   = nil
        
        unCachedPeripheral(peripheralUUID)
        
        guard let peripheral = connectedPeripherals.first(where: { $0.identifier == peripheralUUID}) else {
            return
        }
        
        for (_, characteristics) in peripheralCharacteristics {
            
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
            self.processReadTransationResponse(forCharacteristic: characteristic, from: peripheral.identifier, error: error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        dataQueue.async { [unowned self] in
            self.processWriteTransationResponse(forCharacteristic : characteristic, from : peripheral.identifier)
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
        
        Log(.debug, logString: "Discovered Services:")
        
        for service in services {
            Log(.debug, logString: "        - \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // TODO: Break Up This Method and Test It
    internal func handleCharacteristicsDiscovered(for service: CBService, on peripheral: CBPeripheral, _ error: Error?) {
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        Log(.debug, logString: "Service: \(service.uuid.uuidString)")
        Log(.debug, logString: "          - Characteristics:")
        
        for characteristic in characteristics {
            Log(.debug, logString: "             - \(characteristic.uuid.uuidString)")
            
            if !(peripheralCharacteristics[peripheral.identifier]?.contains(characteristic))! {
                
                peripheralCharacteristics[peripheral.identifier]!.append(characteristic)
                
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
            
            for (peripheralUUID, _) in self.peripheralCharacteristics {
                
                if let characteristic = self.characteristic(for: uuid, on: peripheralUUID) {
                    
                    guard let transaction = self.writeTransaction(for : characteristic,
                                                                  to  : peripheralUUID) else {
                                                                    return
                    }
                    
                    transaction.data = data
                    
                    if completion != nil { transaction.completion = completion }
                    
                    guard let peripheral = self.connectedPeripherals.first(where: { $0.identifier == peripheralUUID}) else {
                        return
                    }
                    
                    for packet in transaction.dataPackets {
                        peripheral.writeValue(packet, for: characteristic, type: .withResponse)
                    }
                }
            }
        }
    }
    
    public func read(fromUUID uuid: String, completion : EBTransactionCallback? = nil) {
        
        dataQueue.async { [unowned self] in
            for (peripheralUUID, _) in self.peripheralCharacteristics {
                
                if let characteristic = self.characteristic(for: uuid, on: peripheralUUID) {
                    
                    guard let transaction = self.readTransaction(for : characteristic,
                                                                 from : peripheralUUID) else {
                                                                    return
                    }
                    
                    if completion != nil { transaction.completion = completion }
                    
                    guard let peripheral = self.connectedPeripherals.first(where: { $0.identifier == peripheralUUID}) else {
                        return
                    }
                    
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }
}

extension EBCentralManager {
    
    // TODO: Test This Method
    internal func processWriteTransationResponse(forCharacteristic characteristic: CBCharacteristic, from peripheralUUID: UUID) {
        
        guard let transaction = writeTransaction(for : characteristic, to  : peripheralUUID) else {
            return
        }
        
        transaction.processTransaction()
        
        Log(.debug, logString: "Central Send Write Packet  \(transaction.activeResponseCount)  / \(transaction.totalPackets)")
        
        if transaction.isComplete {
            Log(.debug, logString: "Central Write Compelete")
            transaction.completion?(transaction.data!, nil)
            clearWriteTransaction(from: peripheralUUID, on: characteristic)
        }
    }
    
    // TODO: Test This Method
    internal func processReadTransationResponse(forCharacteristic characteristic: CBCharacteristic, from peripheralUUID: UUID, error: Error?) {
        
        if characteristic.uuid.uuidString == mtuCharacteristicUUIDKey &&
            chunkedCharacteristicUUIDS.count > 0 {
            handleMTUValueUpdate(for: characteristic, on: peripheralUUID)
            return
        }
        
        guard let transaction = readTransaction(for: characteristic, from: peripheralUUID) else {
            return
        }
        
        transaction.appendPacket(characteristic.value)
        transaction.processTransaction()
        
        Log(.debug, logString: "Central Received Read Packet  \(transaction.activeResponseCount)  / \(transaction.totalPackets)")
        
        if transaction.isComplete {
            Log(.debug, logString: "Central Read Compelete")
            
            transaction.completion?(transaction.data!, nil)
            clearReadTransaction(from: peripheralUUID, on: characteristic)
        } else {
            read(fromUUID : characteristic.uuid.uuidString)
        }
    }
}

extension EBCentralManager {
    
    internal func handleMTUValueUpdate(for characteristic : CBCharacteristic, on peripheralUUID : UUID) {
        
        guard let value =  characteristic.value?.int16Value(inRange: 0..<2) else {
            return
        }
        
        Log(.debug, logString: "Received MTU \(value)\n");
        
        peripheralMTUValues[peripheralUUID] = value
        
        guard let peripheral = connectedPeripherals.first(where: { $0.identifier == peripheralUUID}) else {
            return
        }
        
        peripheralConnectionCallback?(true, peripheral, nil)
    }
}

extension EBCentralManager {
    
    // TODO: Test This Method
    internal func writeTransaction(for characteristic : CBCharacteristic,
                                   to peripheralUUID : UUID) -> Transaction? {
        
        var activeWriteTransation = activeWriteTransations[peripheralUUID]?.first(where: {
            $0.characteristic?.uuid == characteristic.uuid
        })
        
        if activeWriteTransation != nil  {
            return activeWriteTransation
        }
        
        if activeWriteTransations[peripheralUUID] == nil {
            activeWriteTransations[peripheralUUID] = [Transaction]()
        }
        
        var transactionType : TransactionType = .write
        
        if let _  = chunkedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .writeChunkable
        }
        
        guard let mtuValue = self.peripheralMTUValues[peripheralUUID] else {
            Log(.debug, logString: "Central to Peripheral MTU Value Not Found")
            return nil
        }
        
        activeWriteTransation = Transaction(transactionType,
                                            .centralToPeripheral,
                                            characteristic : characteristic,
                                            mtuSize : mtuValue)
        
        activeWriteTransations[peripheralUUID]!.append(activeWriteTransation!)
        
        return activeWriteTransation
    }
    
    // TODO: Test This Method
    internal func readTransaction(for characteristic : CBCharacteristic,
                                  from peripheralUUID : UUID) -> Transaction? {
        
        var activeReadTransation = activeReadTransations[peripheralUUID]?.first(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased()
        })
        
        if activeReadTransation != nil  {
            return activeReadTransation
        }
        
        if self.activeReadTransations[peripheralUUID] == nil {
            self.activeReadTransations[peripheralUUID] = [Transaction]()
        }
        
        var transactionType : TransactionType = .read
        
        if let _  = self.chunkedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .readChunkable
        }
        
        activeReadTransation = Transaction(transactionType, .centralToPeripheral,
                                           characteristic : characteristic)
        
        self.activeReadTransations[peripheralUUID]!.append(activeReadTransation!)
        
        return activeReadTransation
    }
    
    // TODO: Test This Method
    internal func characteristic(for uuid: String, on peripheralUUID : UUID) -> CBCharacteristic? {
        
        if let characteristic = self.peripheralCharacteristics[peripheralUUID]?.first(where:
            { $0.uuid.uuidString.uppercased() == uuid.uppercased() })
        {
            return characteristic
        }
        
        return nil
    }
    
    // TODO: Test This Method
    internal func clearReadTransaction(from peripheralUUID: UUID, on characteristic : CBCharacteristic) {
        if let index = self.activeReadTransations[peripheralUUID]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeReadTransations[peripheralUUID]?.remove(at: index)
        }
    }
    
    // TODO: Test This Method
    internal func clearWriteTransaction(from peripheralUUID: UUID, on characteristic : CBCharacteristic) {
        if let index = self.activeWriteTransations[peripheralUUID]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeWriteTransations[peripheralUUID]?.remove(at: index)
        }
    }
}

extension EBCentralManager {
    
    internal func cachePeripheral(_ peripheralUUID : UUID) {
        
        guard reconnectOnStart else {
            return
        }
        
        let defaults = UserDefaults.standard
        
        if var uuids = defaults.array(forKey: reconnectCacheKey) as? [String], !uuids.contains(peripheralUUID.uuidString) {
            
            uuids.append(peripheralUUID.uuidString)
            defaults.set(uuids, forKey : reconnectCacheKey)
            
        } else {
            defaults.set([peripheralUUID.uuidString], forKey : reconnectCacheKey)
        }
        
        defaults.synchronize()
    }
    
    internal func unCachedPeripheral(_ peripheralUUID : UUID) {
        
        guard reconnectOnStart else {
            return
        }
        
        let defaults = UserDefaults.standard
        
        if var uuids = defaults.array(forKey: reconnectCacheKey) as? [String] {
            
            if let index = uuids.index(of: peripheralUUID.uuidString) {
                uuids.remove(at: index)
            }
            
            defaults.set(uuids, forKey : reconnectCacheKey)
            defaults.synchronize()
        }
    }
    
    internal func cachedPeripherals() -> [CBPeripheral]? {
        
        guard reconnectOnStart else {
            return nil
        }
        
        guard let uuids = UserDefaults.standard.array(forKey: reconnectCacheKey) as? [String],
            let uuidArray = uuids.map({ UUID(uuidString: $0) }) as? [UUID] else {
                return nil
        }
        
        let peripherals = centralManager.retrievePeripherals(withIdentifiers:uuidArray)
        
        guard peripherals.count != 0 else {
            return nil
        }
        
        for peripheral in peripherals {
            peripheralCharacteristics[peripheral.identifier] = [CBCharacteristic]()
        }
        
        return peripherals
    }
}
