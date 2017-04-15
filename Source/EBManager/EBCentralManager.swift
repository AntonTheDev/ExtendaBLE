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
    internal var managerOptions             = [String : Any]()
    internal var scanOptions                = [String : Any]()
    internal var connectionOptions          = [String : Any]()
    
    // Services Defined during creation
    internal var registeredServiceUUIDs             = [CBUUID]()
    internal var packetBasedCharacteristicUUIDS     = [CBUUID]()
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
        
        if let options = options  {
            managerOptions = options
        }
        
        centralManager = CBCentralManager(delegate: self, queue:  (queue == nil ? queue : operationQueue), options: managerOptions)
    }
}

// MARK: - Peripheral Discovery

extension EBCentralManager {
    
    public var isScanning: Bool {
        get {
            #if os(OSX)
                return _isScanning
            #else
                return centralManager.isScanning
            #endif
        }
        set {
            #if os(OSX)
                _isScanning = false
            #endif
        }
    }
    
    @discardableResult public func startScan() -> EBCentralManager {
        
        if centralManager.state != .poweredOn { return self }
        
        if reconnectOnStart {
            pairConnectedPeripherals()
        } else {
            scanForPeripherals()
        }
        
        return self
    }
    
    @discardableResult public func stopScan() -> EBCentralManager {
        Log(.debug, logString: "Stopped Scan")
        
        centralManager.stopScan()
        isScanning = false
        
        scheduleRescanIfNeeded()
        
        return self
    }
    
    internal func scanForPeripherals() {
        Log(.debug, logString: "Started Scan")
        
        invalidateScheduledRescan()
        centralManager.scanForPeripherals(withServices: self.registeredServiceUUIDs,
                                          options: self.scanOptions)
        isScanning = true
    }
    
    func scheduleRescanIfNeeded() {
        
        if (rescanInterval > 0 && supportMutiplePeripherals) ||
            (connectedPeripherals.count == 0 && !supportMutiplePeripherals)
        {
            rescanTimer?.invalidate()
            rescanTimer =   Timer(fireAt: Date().addingTimeInterval(rescanInterval),
                                  interval: 0.0,
                                  target: self,
                                  selector: #selector(scanForPeripherals),
                                  userInfo: nil,
                                  repeats: false)
        }
    }
    
    func invalidateScheduledRescan() {
        rescanTimer?.invalidate()
        rescanTimer = nil
    }
}

// MARK: - Peripheral Connection

extension EBCentralManager {
    
    func connect(to peripheral : CBPeripheral,
                 _ advertisementData: [String : Any]? = nil,
                 _ RSSI: NSNumber? = nil) {
        
        if isValidPeripheral(peripheral, advertisementData, RSSI) {
            
            Log(.debug, logString: "Connecting to \(String(describing: peripheral.name))")
            
            connectedPeripherals.append(peripheral)
            peripheralCharacteristics[peripheral.identifier] = [CBCharacteristic]()
            
            centralManager.connect(peripheral, options: connectionOptions)
            
            if supportMutiplePeripherals == false {
                stopScan()
            }
        }
    }
    
    internal func disconnect(from peripheralUUID : UUID, _ error: Error?) {
        
        Log(.debug, logString: "Disconnect from \(String(describing: peripheralUUID)) - \(String(describing: error))")
        
        activeWriteTransations      = [UUID : [Transaction]]()
        activeReadTransations       = [UUID : [Transaction]]()
        
        peripheralMTUValues         = [UUID : Int16]()
        peripheralCharacteristics   = [UUID : [CBCharacteristic]]()
        
        unpairPeripheral(peripheralUUID)
        
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
    
    internal func isValidPeripheral(_ peripheral : CBPeripheral,
                                    _ advertisementData: [String : Any]? = nil,
                                    _ RSSI: NSNumber? = nil) -> Bool {
        if peripheral.state == .connected {
            return false
        }
        
        guard let isConnectable = advertisementData?[CBAdvertisementDataIsConnectable] as? Bool, isConnectable else {
            return false
        }
        
        guard connectedPeripherals.contains(peripheral) == false else {
            return false
        }
        
        Log(.debug, logString: "Advertisement Name \(String(describing: advertisementData?[CBAdvertisementDataLocalNameKey]))")
        
        if let name = advertisementData?[CBAdvertisementDataLocalNameKey] as? String, name == peripheralName {
            return true
        }
        
        if let peripheralUUIDs = advertisementData?[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            
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
}

// MARK: - Caching Peripherals

extension EBCentralManager {
    
    internal var pairedPeripherals : [CBPeripheral]? {
        get {
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
    
    
    internal func pairConnectedPeripherals() {
        
        let peripherals = pairedPeripherals
        
        if reconnectOnStart == false || peripherals != nil {
            scanForPeripherals()
            return
        }
        
        for peripheral in peripherals! {
            
            Log(.debug, logString: "Central Found Cached Peripheral \(String(describing: peripheral.name)), Attempting to Connect")
            
            connect(to: peripheral)
            
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + reconnectTimeout, execute: { [unowned self] in
                if peripheral.state != .connected {
                    Log(.debug, logString: "Failed to Reconnect To \(String(describing: peripheral.name)), Attempting to Scan")
                    self.unpairPeripheral(peripheral.identifier)
                    self.scanForPeripherals()
                }
            })
        }
    }
    
    internal func pairPeripheral(_ peripheralUUID : UUID) {
        
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
    
    internal func unpairPeripheral(_ peripheralUUID : UUID) {
        
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
}

// MARK: - Service Discovery

extension EBCentralManager {
    
    internal func discoverRegisteredServices(on peripheral : CBPeripheral) {
        
        Log(.debug, logString: "Connected to \(String(describing: peripheral.name))")
        Log(.debug, logString: "Discovering Services")
        
        peripheral.delegate = self
        peripheral.discoverServices(registeredServiceUUIDs)
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
    internal func discoveredCharactetistics(forService service: CBService, from peripheral: CBPeripheral, _ error: Error?) {
        
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
        
        if packetBasedCharacteristicUUIDS.count == 0 {
            peripheralConnectionCallback?(true, peripheral, nil)
        }
    }
}

// MARK: - Write

extension EBCentralManager {
    
    public func write(data : Data, toUUID uuid: String, completion : EBTransactionCallback? = nil) {
        
        dataQueue.async { [unowned self] in
            for (peripheralUUID, _) in self.peripheralCharacteristics {
                
                if let characteristic = self.characteristic(for: uuid, on: peripheralUUID) {
                    
                    guard let transaction = self.writeTransaction(for : characteristic, to : peripheralUUID) else {
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
    
    // Test This Method
    internal func receivedWriteResponse(forCharacteristic characteristic: CBCharacteristic, from peripheralUUID: UUID) {
        
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
    
    // Test This Method
    internal func writeTransaction(for characteristic : CBCharacteristic,
                                   to peripheralUUID : UUID) -> Transaction? {
        
        var activeWriteTransation = activeWriteTransations[peripheralUUID]?.first(where: {
            $0.characteristic?.uuid == characteristic.uuid
        })
        
        if activeWriteTransation != nil  {
            return activeWriteTransation
        }
        
        var transactionType : TransactionType = .write
        
        if let _  = packetBasedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .writePackets
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
    
    // Test This Method
    internal func clearWriteTransaction(from peripheralUUID: UUID, on characteristic : CBCharacteristic) {
        if let index = self.activeWriteTransations[peripheralUUID]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeWriteTransations[peripheralUUID]?.remove(at: index)
        }
    }
}

// MARK: - Read

extension EBCentralManager {
    
    public func read(characteristicUUID uuid: String, completion : EBTransactionCallback? = nil) {
        
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
    
    // Test This Method
    internal func receivedReadResponse(forCharacteristic characteristic: CBCharacteristic, from peripheralUUID: UUID, error: Error?) {
        
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
            read(characteristicUUID : characteristic.uuid.uuidString)
        }
    }
    
    // Test This Method
    internal func readTransaction(for characteristic : CBCharacteristic,
                                  from peripheralUUID : UUID) -> Transaction? {
        
        var activeReadTransation = activeReadTransations[peripheralUUID]?.first(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased()
        })
        
        if activeReadTransation != nil  {
            return activeReadTransation
        }
        
        var transactionType : TransactionType = .read
        
        if let _  = self.packetBasedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .readPackets
        }
        
        activeReadTransation = Transaction(transactionType, .centralToPeripheral,
                                           characteristic : characteristic)
        
        self.activeReadTransations[peripheralUUID]!.append(activeReadTransation!)
        
        return activeReadTransation
    }
    
    // Test This Method
    internal func clearReadTransaction(from peripheralUUID: UUID, on characteristic : CBCharacteristic) {
        if let index = self.activeReadTransations[peripheralUUID]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeReadTransations[peripheralUUID]?.remove(at: index)
        }
    }
}

// MARK: - Read / Write Response

extension EBCentralManager {
    
    internal func respondToManagerStateChange(_ central: CBCentralManager) {
        Log(.debug, logString: "Central BLE state - \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            operationQueue.async { [unowned self] in
                self.startScan()
            }
        default:
            break
        }
        
        stateChangeCallBack?(EBManagerState(rawValue: central.state.rawValue)!)
    }
    
    internal func handleMTUValueUpdate(for characteristic : CBCharacteristic, from peripheral: CBPeripheral) {
        
        guard let value = characteristic.value?.int16Value(inRange: 0..<2) else {
            return
        }
        
        Log(.debug, logString: "Received MTU \(value)\n");
        
        if let _ = peripheralMTUValues[peripheral.identifier] {
            peripheralMTUValues[peripheral.identifier] = value
            return
        }
        
        peripheralMTUValues[peripheral.identifier] = value
        
        guard let peripheral = connectedPeripherals.first(where: { $0.identifier == peripheral.identifier}) else {
            return
        }
        
        peripheralConnectionCallback?(true, peripheral, nil)
    }
}

extension EBCentralManager {
    

    
    // TODO: Test This Method
    internal func characteristic(for uuid: String, on peripheralUUID : UUID) -> CBCharacteristic? {
        
        if let characteristic = self.peripheralCharacteristics[peripheralUUID]?.first(where:
            { $0.uuid.uuidString.uppercased() == uuid.uppercased() })
        {
            return characteristic
        }
        
        return nil
    }
    
    internal func handleNotificationStateUpdate(_ peripheral: CBPeripheral, _ characteristic: CBCharacteristic, _ error: Error?) {
        let notificationState  = characteristic.isNotifying ? "Registered" : "Unregistered"
        Log(.debug, logString: "\(notificationState) Notification for characteristic")
        Log(.debug, logString: "        -  \(characteristic.uuid)")
    }
}
