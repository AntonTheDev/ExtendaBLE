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
    
    /// Central manager instance
    internal var centralManager             : CBCentralManager!
    
    /// The peripheral name to search for, the central will attempt to connect if defined
    /// otherwise it will scan for registered services defined during constructions only
    internal var peripheralName             : String?
    
    /// If multiple peripherals are supported, a scan will begin after reconnecting 
    /// to paied peripherals
    internal var supportMutiplePeripherals  = false
    
    /// Reconnect on start stores devices we haev connected to prior
    internal var reconnectOnStart           = true
    
    /// NSUserdefautls key for tracking paired peripheral uuids
    internal var reconnectCacheKey          = "EBCentralManagerDefaultPeripheralCacheKey"
    
    /// Time interval to way before scanning while attempting to recoonect to paied peripherals
    internal var reconnectTimeout           = 2.0
    
    /// If no devices are found it will rescan after the internal specified, defailt is 0
    internal var rescanInterval             = 0.0
    
    /// If the rescan internval is defined, this is the timer that is used to scan again
    internal var rescanTimer : Timer?
    
    /// Scan timeout internval if no peripherals are found
    internal var scanTimeout                = 10.0
    
    // Central manager options, defined during creation
    internal var managerOptions             = [String : Any]()
    
    /// Scan options used for discovering peripherals, determined during creation
    internal var scanOptions                = [String : Any]()
    
    /// Connection optiosn used when connecting to a peripheral, determined during creation
    internal var connectionOptions          = [String : Any]()
    
    /// Array of registered setvice UUIDs, used for service discovery
    internal var registeredServiceUUIDs             = [CBUUID]()
    
    /// Array of packet based characteristics, determines how reads/writes are handled
    internal var packetBasedCharacteristicUUIDS     = [CBUUID]()
    
    /// Callsbacks associated with updates from the peripheral
    internal var registeredCharacteristicCallbacks  = [CBUUID : EBTransactionCallback]()
    
    // TODO: Make sure to remove the peripheral on disconnect and set the delegate to nill
    internal var connectedPeripherals               = [CBPeripheral]()
    
    // Discovered characteristics associated with a peripheral, user to read/write
    internal var peripheralCharacteristics          = [UUID : [CBCharacteristic]]()
    
    /// Synchronized MTU Value for connected peripherals
    internal var peripheralMTUValues                = [UUID : Int16]()
    
    /// Currently active write transactions, associated with a peripheral uuid
    internal var activeWriteTransations             = [UUID : [Transaction]]()
    
    /// Currently active read transactions, associated with a peripheral uuid
    internal var activeReadTransations              = [UUID : [Transaction]]()

    /// Default operation queue for the central manager if not specified, also used for non data operations
    internal var operationQueue                     = DispatchQueue(label: "CentralManagerQueue", qos: .userInitiated)
    
    /// All data operations are handled on this queue, read / write are synchronous
    internal var dataQueue                          = DispatchQueue(label: "CentralManagerOperationQueue", qos: .userInitiated)
    
    /// State change delegate callback, specify during creation
    internal var stateChangeCallBack                : CentralManagerStateChangeCallback?
    
    /// Did Discover peripheral callback, if you manually want to connect, specify during creation
    internal var didDiscoverCallBack                : CentralManagerDidDiscoverCallback?
    
    /// Connection connection state change delegate callback, specify during creation
    internal var peripheralConnectionCallback       : CentralManagerPeripheralConnectionCallback?
    
    /// Internal flag to ensure a scan starts if the user attempts to start scanning before the central is powered on
    internal var scanningRequested  = false
    
    #if os(OSX)
    /// Internal flag for OSX, since the central does not report if it is scanning on OSX
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


// MARK: - CBCentralManagerDelegate
extension EBCentralManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        operationQueue.async { [unowned self] in
            self.respondToManagerStateChange(central)
        }
    }
    
    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String : Any],
                               rssi RSSI: NSNumber) {
        
        print(peripheral)
        operationQueue.async { [unowned self] in
            self.connect(to : peripheral, advertisementData, RSSI, false)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        operationQueue.async { [unowned self] in
            if let peripheralIdentifier = peripheral.value(forKey: "identifier") as? UUID {
                self.pairPeripheral(peripheralIdentifier)
                self.discoverRegisteredServices(on: peripheral)
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        operationQueue.async { [unowned self] in
            if let centralIdentifier = central.value(forKey: "identifier") as? UUID {
                self.disconnect(from : centralIdentifier, error)
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        operationQueue.async { [unowned self] in
            if let peripheralIdentifier = peripheral.value(forKey: "identifier") as? UUID {
                self.disconnect(from : peripheralIdentifier, error)
            }
        }
    }
    
    /*
     #if os(iOS) || os(tvOS)
     public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
     
     }
     #endif
     */
}


// MARK: - CBPeripheralDelegate
extension EBCentralManager: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        operationQueue.async { [unowned self] in
            self.handleServicesDiscovered(for : peripheral, error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        operationQueue.async { [unowned self] in
            self.discoveredCharactetistics(forService : service, from : peripheral, error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        dataQueue.async { [unowned self] in
            if let peripheralIdentifier = peripheral.value(forKey: "identifier") as? UUID {
                self.receivedReadResponse(forCharacteristic: characteristic, from: peripheralIdentifier, error: error)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        dataQueue.async { [unowned self] in
            if let peripheralIdentifier = peripheral.value(forKey: "identifier") as? UUID {
                self.receivedWriteResponse(forCharacteristic : characteristic, from : peripheralIdentifier)
            }
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
}


// MARK: - Peripheral Discovery
extension EBCentralManager {
    
    /// Wrapper around isScanning to support multiple platforms
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
    
    
    /// Start scanning for peripherals by calling this method
    public func startScan() {
        if centralManager.state != .poweredOn {
            scanningRequested = true
            return
        }
        
        if reconnectOnStart {
            pairConnectedPeripherals()
        } else {
            scanForPeripherals()
        }
    }
    
    
    /// Stop scanning for peripherals by calling this method
    public func stopScan() {
        Log(.debug, logString: "Stopped Scan")
        
        centralManager.stopScan()
        isScanning = false
        
        scheduleRescanIfNeeded()
    }
    
    
    /// Internal trigger for scanning, called ass needed
    @objc internal func scanForPeripherals() {
        Log(.debug, logString: "Started Scan")
        
        invalidateScheduledRescan()
        centralManager.scanForPeripherals(withServices: self.registeredServiceUUIDs,
                                          options: self.scanOptions)
        isScanning = true
    }
    
    
    /// Internal trigger for the rescan timmer
    internal func scheduleRescanIfNeeded() {
        if (rescanInterval > 0 && supportMutiplePeripherals) ||
            (connectedPeripherals.count == 0 && !supportMutiplePeripherals) {
            rescanTimer?.invalidate()
            rescanTimer =   Timer(fireAt: Date().addingTimeInterval(rescanInterval),
                                  interval: 0.0,
                                  target: self,
                                  selector: #selector(scanForPeripherals),
                                  userInfo: nil,
                                  repeats: false)
        }
    }
    
    
    /// Internal method to stop the rescan timer
    func invalidateScheduledRescan() {
        rescanTimer?.invalidate()
        rescanTimer = nil
    }
}


// MARK: - Peripheral Connection
extension EBCentralManager {
    
    /// Called by the cenrtral manager delegate upon finding a peripheral, if the
    /// didDiscoverCallBack is not defined. It is up to the developer to manually call
    /// this method to connect to a peripheral other wise. The overrideValidation is
    /// set to false internal if the conenction is attempted automatically, other wise
    /// if the attempting to reconnect to a paired peripheral, or it is user initiated
    /// the validation is ignored.
    ///
    /// - Parameters:
    ///   - peripheral: peripheral discover
    ///   - advertisementData: advertisement data for the peripheral
    ///   - RSSI: RSSI for discovered peripheral
    ///   - overrideValidation: flag used internal to force validation
    public func connect(to peripheral : CBPeripheral,
                 _ advertisementData: [String : Any]? = nil,
                 _ RSSI: NSNumber? = nil,
                 _ overrideValidation : Bool = true) {
        
        if overrideValidation || isValidPeripheral(peripheral, advertisementData, RSSI) {
            
            Log(.debug, logString: "Connecting to \(String(describing: peripheral.name))")
            
            connectedPeripherals.append(peripheral)
            
            if let peripheralIdentifier = peripheral.value(forKey: "identifier") as? UUID {
                peripheralCharacteristics[peripheralIdentifier] = [CBCharacteristic]()
                
                centralManager.connect(peripheral, options: connectionOptions)
                
                if supportMutiplePeripherals == false {
                    stopScan()
                }
            }
        }
    }
    
    
    /// Clears all the data associated associated with the peripheral when disconnect occurs,
    /// this is called on didFailToConnect and didDisconnect, can also be manually triggered
    ///
    /// - Parameters:
    ///   - peripheralUUID: the peripheral uuid to disconnect
    ///   - error: error
    internal func disconnect(from peripheralUUID : UUID, _ error: Error?) {
        
        Log(.debug, logString: "Disconnect from \(String(describing: peripheralUUID)) - \(String(describing: error))")
        
        activeWriteTransations      = [UUID : [Transaction]]()
        activeReadTransations       = [UUID : [Transaction]]()
        
        peripheralMTUValues         = [UUID : Int16]()
        peripheralCharacteristics   = [UUID : [CBCharacteristic]]()
        
        unpairPeripheral(peripheralUUID)
    
        guard let peripheral = connectedPeripherals.first(where: { $0.value(forKey: "identifier") as? UUID == peripheralUUID}) else {
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
    
    
    /// This method validates and returns true if the discovered peripheral is valid according
    /// to the services, or peripheral name defined during scanning.
    ///
    /// - Parameters:
    ///   - peripheral: the peripheral that was discovered
    ///   - advertisementData: the advertisement data associated with the peripheral
    ///   - RSSI: the RSSI for discovered peripheral
    /// - Returns: true if the peripheral fits the registered criteria
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
    
    /// Internal variable to retrieve paired peripherals
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
                
                if let peripheralIdentifier = peripheral.value(forKey: "identifier") as? UUID {
                   peripheralCharacteristics[peripheralIdentifier] = [CBCharacteristic]()
                }
            }
            
            return peripherals
        }
    }

    
    /// Internal method to attempt to pair periviously connected devices
    internal func pairConnectedPeripherals() {
        
        let peripherals = pairedPeripherals
        
        if reconnectOnStart == false || peripherals != nil {
            scanForPeripherals()
            return
        }
        
        for peripheral in peripherals! {
            
            Log(.debug, logString: "Central Found Cached Peripheral \(String(describing: peripheral.name)), Attempting to Connect")
            
            connect(to: peripheral, nil, nil, true)
            
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + reconnectTimeout, execute: { [unowned self] in
                if peripheral.state != .connected {
                    Log(.debug, logString: "Failed to Reconnect To \(String(describing: peripheral.name)), Attempting to Scan")
                    if let peripheralIdentifier = peripheral.value(forKey: "identifier") as? UUID {
                        self.unpairPeripheral(peripheralIdentifier)
                        self.scanForPeripherals()
                    }
                }
            })
        }
    }
    
    
    /// If peripheral caching is enabled, called after the peripheral has connected
    /// to cache the peripheral uuid in the nsuserdefaults
    ///
    /// - Parameter peripheralUUID: peripheral uuid to cache
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
    
    
    /// If the peripheral was cached and cannot be found, this is called
    /// to removce the peripheral uuid from the nsuserdefaults
    ///
    /// - Parameter peripheralUUID: peripheral uuid to remove from cache
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
    
    /// Called after connecting to the peripheral to discover services
    ///
    /// - Parameter peripheral: the peripheral to discover services on
    internal func discoverRegisteredServices(on peripheral : CBPeripheral) {
        
        Log(.debug, logString: "Connected to \(String(describing: peripheral.name))")
        Log(.debug, logString: "Discovering Services")
        
        peripheral.delegate = self
        peripheral.discoverServices(registeredServiceUUIDs)
    }
    
    
    /// Once a service has been discovered, a call is made to this method
    /// to store them in the peripheralCharacteristics dictioanry
    /// as an internal reference. Once the service has been discovvered,
    /// a call is made to discover chracterics on that service
    ///
    /// - Parameters:
    ///   - peripheral: peripheral for which the services were found
    ///   - error: error returned if there was an issue with service discovery
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
    
    
    /// Once a characteristic has been discoved for a service on a specific peripheral
    /// a call to this method will store the characteristics for the associated peripheral
    /// for later ference
    ///
    /// - Parameters:
    ///   - service: service for which characteristics were discovered
    ///   - peripheral: associated peripheral for associated service
    ///   - error: error if there was an issue during characteristic discovery
    internal func discoveredCharactetistics(forService service: CBService, from peripheral: CBPeripheral, _ error: Error?) {
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        Log(.debug, logString: "Service: \(service.uuid.uuidString)")
        Log(.debug, logString: "          - Characteristics:")
        
        for characteristic in characteristics {
            Log(.debug, logString: "             - \(characteristic.uuid.uuidString)")
            
            if let peripheralIdentifier = peripheral.value(forKey: "identifier") as? UUID {
                if !(peripheralCharacteristics[peripheralIdentifier]?.contains(characteristic))! {
                    peripheralCharacteristics[peripheralIdentifier]!.append(characteristic)
                    
                    if characteristic.uuid.uuidString.uppercased() == mtuCharacteristicUUIDKey {
                        if characteristic.properties.contains(.notify) {
                            Log(.debug, logString: "Triggered Notification Registration for: \(characteristic.uuid.uuidString)")
                            peripheral.setNotifyValue(true, for: characteristic)
                        }
                    }
                }
            }
            
           
        }
        
        if packetBasedCharacteristicUUIDS.count == 0 {
            peripheralConnectionCallback?(true, peripheral, nil)
        }
    }
}


// MARK: - Helpers
extension EBCentralManager {
    
    /// Returns the connected characteristic associated with the peripheral UUID
    ///
    /// - Parameters:
    ///   - characteristicUUID: the characteristic UUID to find
    ///   - peripheralUUID: the associated peripherial with the characterixtic
    /// - Returns: the characteristic if instance, if found
    internal func characteristic(for characteristicUUID: String, on peripheralUUID : UUID) -> CBCharacteristic? {
        
        if let characteristic = self.peripheralCharacteristics[peripheralUUID]?.first(where:
            { $0.uuid.uuidString.uppercased() == characteristicUUID.uppercased() })
        {
            return characteristic
        }
        
        return nil
    }
}


// MARK: - Write
extension EBCentralManager {

    /// Write data to the peripheral with the associated characteristic. The method
    /// will find all the associated connected peripherals registered to the 
    /// and will post the data to those peripherals.
    ///
    /// - Parameters:
    ///   - data: the data stream to send to the peripheral
    ///   - characteristicUUID: the associated characteristic uuid to send write
    ///   - completion: completion callback called once the write is complete
    public func write(data : Data, toUUID characteristicUUID: String, completion : EBTransactionCallback? = nil) {
        
        dataQueue.async { [unowned self] in
            for (peripheralUUID, _) in self.peripheralCharacteristics {
                
                if let characteristic = self.characteristic(for: characteristicUUID, on: peripheralUUID) {
                    
                    guard let transaction = self.writeTransaction(for : characteristic, to : peripheralUUID) else {
                        return
                    }
                    
                    transaction.data = data
                    
                    if completion != nil { transaction.completion = completion }
               
                    guard let peripheral = self.connectedPeripherals.first(where: { $0.value(forKey: "identifier") as? UUID == peripheralUUID}) else {
                        return
                    }
                    
                    for packet in transaction.dataPackets {
                        peripheral.writeValue(packet, for: characteristic, type: .withResponse)
                    }
                }
            }
        }
    }
    
    
    /// Called my by the peripheral delegate for a successful write response. If the
    /// characteristic supports packets, it will continue to perform write calls until
    /// all the packets are awknowledged by the peripheral.
    ///
    /// - Parameters:
    ///   - characteristic: the characteristic responding to the write request
    ///   - peripheralUUID: the peripheral uuid to write to
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
    
    
    /// Generate a write transactions if there isn't one in the queue already,
    /// otherwise it regenerates one, and stores it in the activeWriteTransations
    /// dictionary. The transaction keeps track of the packets sent to the peripheral.
    ///
    /// - Parameters:
    ///   - characteristic: characteristic to write to
    ///   - peripheralUUID: peripheral uuid to write to
    /// - Returns: new or existing write transaction instance for the operation
    internal func writeTransaction(for characteristic : CBCharacteristic,
                                   to peripheralUUID : UUID) -> Transaction? {
        
        var activeWriteTransation = activeWriteTransations[peripheralUUID]?.first(where: {
            $0.characteristic?.uuid == characteristic.uuid
        })
        
        if activeWriteTransation != nil  {
            return activeWriteTransation
        }
        
        if self.activeWriteTransations[peripheralUUID] == nil {
            self.activeWriteTransations[peripheralUUID] = [Transaction]()
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
    
    
    /// Clears the transation instance upon completion
    ///
    /// - Parameters:
    ///   - peripheralUUID: the peripheral uuid to write to
    ///   - characteristic: the characteristic written to
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

    /// Read data from the peripheral for the associated characteristic uuid. 
    /// The method will find the connected peripheral registered, and trigger
    /// a read request. If the characteristic is packet based, it will keep
    /// triggering read requests until all the packets are received, before 
    /// reconstructing the data, and calling the completion callback
    ///
    /// - Parameters:
    ///   - uuid: the associated characteristic uuid to read
    ///   - completion: completion callback called once the read is complete
    public func read(characteristicUUID uuid: String, completion : EBTransactionCallback? = nil) {
        
        dataQueue.async { [unowned self] in
            
            for (peripheralUUID, _) in self.peripheralCharacteristics {
                
                if let characteristic = self.characteristic(for: uuid, on: peripheralUUID) {
                    
                    guard let transaction = self.readTransaction(for : characteristic,
                                                                 from : peripheralUUID) else {
                                                                    return
                    }
                    
                    if completion != nil { transaction.completion = completion }
                   
                    guard let peripheral = self.connectedPeripherals.first(where: { $0.value(forKey: "identifier") as? UUID == peripheralUUID}) else {
                        return
                    }
                    
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }
    
    
    /// Called my by the peripheral delegate for a successful read response. If the
    /// characteristic supports packets, it will continue to perform read calls until
    /// all the packets are received.
    ///
    /// - Parameters:
    ///   - characteristic: the characteristic responding to the read request
    ///   - peripheralUUID: the peripheral uuid to read from
    ///   - error: error received from the peripheral
    internal func receivedReadResponse(forCharacteristic characteristic: CBCharacteristic,
                                       from peripheralUUID: UUID,
                                       error: Error?) {
        
        guard let transaction = readTransaction(for: characteristic, from: peripheralUUID) else {
            return
        }
        
        transaction.appendPacket(characteristic.value)
        transaction.processTransaction()
        
        Log(.debug, logString: "Central Received Read Packet  \(transaction.activeResponseCount)  / \(transaction.totalPackets)")
        
        if transaction.isComplete {
            Log(.debug, logString: "Central Read Complete")
            
            if transaction.characteristic?.uuid.uuidString == mtuCharacteristicUUIDKey {
                handleMTUValueUpdate(for : transaction.characteristic!, from: peripheralUUID)
            }
            
            transaction.completion?(transaction.data!, nil)
            registeredCharacteristicCallbacks[characteristic.uuid]?(transaction.data, nil)
            
            clearReadTransaction(from: peripheralUUID, on: characteristic)
        } else {
            read(characteristicUUID : characteristic.uuid.uuidString)
        }
    }
    
    
    /// Generate a read transactions if there isn't one in the queue already,
    /// otherwise it regenerates one, and stores it in the activeReadTransations
    /// dictionary. The transaction keeps track of the packets read to the peripheral,
    /// and reconstructs once the read is complete
    ///
    /// - Parameters:
    ///   - characteristic: the characteristic to read
    ///   - peripheralUUID: the peripheral uuid to read from
    /// - Returns: new or existing read transaction instance for the operation
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
        
        if let _  = self.packetBasedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .readPackets
        }
        
        activeReadTransation = Transaction(transactionType, .centralToPeripheral,
                                           characteristic : characteristic)
        
        self.activeReadTransations[peripheralUUID]!.append(activeReadTransation!)
        
        return activeReadTransation
    }
    
    
    /// Clears the transation instance upon completion
    ///
    /// - Parameters:
    ///   - peripheralUUID: the peripheral uuid to written to
    ///   - characteristic: the characteristic written to
    internal func clearReadTransaction(from peripheralUUID: UUID, on characteristic : CBCharacteristic) {
        if let index = self.activeReadTransations[peripheralUUID]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeReadTransations[peripheralUUID]?.remove(at: index)
        }
    }
}


// MARK: Synchronization Handlers
extension EBCentralManager {
    
    internal func respondToManagerStateChange(_ central: CBCentralManager) {
        Log(.debug, logString: "Central BLE state - \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            
            if scanningRequested {
                operationQueue.async { [unowned self] in
                    self.startScan()
                }
            }
        default:
            break
        }
        
        stateChangeCallBack?(EBManagerState(rawValue: central.state.rawValue)!)
    }
    
    internal func handleMTUValueUpdate(for characteristic : CBCharacteristic, from peripheralUUID : UUID) {
        
        guard let value = characteristic.value?.int16Value(inRange: 0..<2) else {
            return
        }
        
        Log(.debug, logString: "Received MTU \(value)\n");
        
        if let _ = peripheralMTUValues[peripheralUUID] {
            peripheralMTUValues[peripheralUUID] = value
            return
        }
        
        peripheralMTUValues[peripheralUUID] = value
     
        guard let peripheral = connectedPeripherals.first(where: { $0.value(forKey: "identifier") as? UUID  == peripheralUUID}) else {
            return
        }
        
        peripheralConnectionCallback?(true, peripheral, nil)
    }
    
    internal func handleNotificationStateUpdate(_ peripheral: CBPeripheral, _ characteristic: CBCharacteristic, _ error: Error?) {
        let notificationState  = characteristic.isNotifying ? "Registered" : "Unregistered"
        Log(.debug, logString: "\(notificationState) Notification for characteristic")
        Log(.debug, logString: "        -  \(characteristic.uuid)")
    }
}
