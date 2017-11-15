//
//  EBPeripheral.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

@available(iOS 9.0, OSX 10.10, *)
public class EBPeripheralManager : NSObject {
    
    /// Peripheral manager instance
    internal var peripheralManager                  : CBPeripheralManager
    
    /// The peripheral name to be included in the advertising data, configured during creation
    internal var localName                          : String?
    
    /// Registered local services to be advertised, configured during creation
    internal var registeredServices                 = [CBMutableService]()
    
    /// Registered callbacks to trigger a characteristic has been written to, configured during creation
    internal var registeredCharacteristicCallbacks  = [CBUUID : EBTransactionCallback]()
    
    /// Array of packet based characteristics, determines how reads/writes are handled
    internal var packetBasedCharacteristicUUIDS     = [CBUUID]()
    
    /// Currently active write transactions, associated with a peripheral uuid
    internal var activeWriteTransations             = [UUID : [Transaction]]()
    
    /// Currently active read transactions, associated with a peripheral uuid
    internal var activeReadTransations              = [UUID : [Transaction]]()
    
    /// Default operation queue for the central manager if not specified, also used for non data operations
    internal var operationQueue                     = DispatchQueue(label: "PeripheralManagerQueue", qos: .userInitiated)
   
    /// All data operations are handled on this queue, read / write are synchronous
    internal var dataQueue                          = DispatchQueue(label: "PeripheralOperationQueue", qos: .default )
    
    /// State change delegate callback, specify during creation
    internal var stateChangeCallBack                : PeripheralManagerStateChangeCallBack?
    
    /// Did start advertising delegate callback
    internal var didStartAdvertisingCallBack        : PeripheralManagerDidStartAdvertisingCallBack?
    
    /// Internal flag to ensure a advertising starts if the user attempts to start advertising before the peripheral is powered on
    internal var advertisingRequested : Bool        = false
    
    @available(iOS 9.0, OSX 10.10, *)
    public required init(queue: DispatchQueue?) {
        #if os(tvOS) || os(watchOS)
            peripheralManager = CBPeripheralManager()
        #else
            peripheralManager = CBPeripheralManager(delegate: nil, queue: queue != nil ? queue : operationQueue)
        #endif
        
        super.init()
        peripheralManager.delegate = self
    }
}


// MARK: - CBPeripheralManagerDelegate
extension EBPeripheralManager: CBPeripheralManagerDelegate {
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        operationQueue.async { [unowned self] in
            self.handleStateChange(on : peripheral)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        dataQueue.sync { [unowned self] in
            self.handleReadRequest(request)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        dataQueue.sync { [unowned self] in
            self.handleWriteRequests(requests)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        operationQueue.async { [unowned self] in
            self.handleSubscription(for : central, on: characteristic)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        operationQueue.async { [unowned self] in
            self.handleUnSubscription(for : central, on: characteristic)
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
         EBLog(.debug, logString: "Started Advertising - Error: \(String(describing: error))")
        didStartAdvertisingCallBack?((error != nil ? false : true), error)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
         EBLog(.debug, logString: "Added Service \(service.uuid.uuidString) - Error: \(String(describing: error))")
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
         EBLog(.debug, logString: "onReadyToUpdateSubscribers")
    }
}


// MARK: - Advertising
extension EBPeripheralManager {
    
    /// Call this method to start advertising the registered services
    public func startAdvertising() {
        
        if peripheralManager.state != .poweredOn {
            peripheralManager.delegate = self
            advertisingRequested = true
            return
        }
        
        peripheralManager.removeAllServices()
        
        for service in registeredServices {
            peripheralManager.add(service)
        }
        
        var advertisementData = [String : Any]()
        
        if let localName = localName {
            advertisementData[CBAdvertisementDataLocalNameKey] = localName
        }
        
        let uuid = registeredServices.filter { $0.isPrimary }.map { $0.uuid }
        advertisementData[CBAdvertisementDataServiceUUIDsKey] = uuid
        peripheralManager.startAdvertising(advertisementData)
    }

    
    /// Call this method to stop advertising
    public func stopAdvertising() {
        peripheralManager.stopAdvertising()
    }
}


// MARK: Write
extension EBPeripheralManager {
    
    /// Called by the peripheral manager delegate once a write requests are
    /// received from the central
    ///
    /// - Parameter requests: requests to process
    internal func handleWriteRequests(_ requests: [CBATTRequest]) {
        
        for request in requests {
            
            if let centralIdentifier = request.central.value(forKey: "identifier") as? UUID {
                if processWriteRequest(packet: request.value,
                                       from: centralIdentifier,
                                       for: request.characteristic,
                                       mtuSize: Int16(request.central.maximumUpdateValueLength)) {
                    
                    peripheralManager.respond(to: request, withResult: .success)
                    
                    if activeWriteTransations[centralIdentifier]?
                        .first(where: { $0.characteristic?.uuid == request.characteristic.uuid }) == nil {
                        processMTUSubscription(for: request.central)
                    }
                }
            }
        }
    }
    
    
    /// The method responds to the delegate call when a write transaction is initiated.
    /// A new transaction will be generated to keep track of all the packets received,
    /// once complete, it will reconstruct the data, and set the value on the local
    /// characteristic instance, and perform updatedValue callback if it exists
    ///
    /// - Parameters:
    ///   - packet: the data packet received
    ///   - centralUUID: the uuid of the sending central
    ///   - characteristic: the characcteristic the value is received for
    ///   - mtuSize: the mtu size that has been synchronized during the connection
    /// - Returns: returns true if value received sucessfully
    internal func processWriteRequest(packet : Data?,
                                      from centralUUID : UUID,
                                      for characteristic: CBCharacteristic,
                                      mtuSize : Int16) -> Bool {
        
        guard let activeWriteTransaction = writeTransaction(for: characteristic,
                                                            from: centralUUID,
                                                            mtuSize: mtuSize) else {
                                                                return false
        }
        
        activeWriteTransaction.appendPacket(packet)
        activeWriteTransaction.processTransaction()
        
         EBLog(.debug, logString: "Peripheral Received Write Packet \(activeWriteTransaction.activeResponseCount) / \(activeWriteTransaction.totalPackets)")
        
        if activeWriteTransaction.isComplete {
             EBLog(.debug, logString: "Peripheral Received Write Complete")
            
            setLocalValue(for: activeWriteTransaction)
            registeredCharacteristicCallbacks[characteristic.uuid]?(activeWriteTransaction.data, nil)
            clearWriteTransaction(from: centralUUID, on: characteristic)
        }
        
        return true
    }
    
    
    /// Generates a write transactions if there isn't one in the queue already,
    /// and stores it in the activeWriteTransations dictionary. The transaction
    /// keeps track of the packets sent to the central until completion
    ///
    /// - Parameters:
    ///   - characteristic: he characcteristic the value is received for
    ///   - centralUUID: the uuid of the sending central
    ///   - mtuSize: the mtu size that has been synchronized during the connection
    /// - Returns: new or existing write transaction instance for the operation
    internal func writeTransaction(for characteristic : CBCharacteristic,
                                   from centralUUID : UUID,
                                   mtuSize : Int16) -> Transaction? {
        
        var activeWriteTransaction = activeWriteTransations[centralUUID]?.first(where: { $0.characteristic?.uuid == characteristic.uuid })
        
        if activeWriteTransaction != nil  {
            return activeWriteTransaction
        }
        
        if activeWriteTransations[centralUUID] == nil {
            activeWriteTransations[centralUUID] = [Transaction]()
        }
        
        var transactionType : TransactionType = .write
        
        if let _  = packetBasedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .writePackets
        }
        
        activeWriteTransaction = Transaction(transactionType, .peripheralToCentral, mtuSize: mtuSize)
        
        for service in registeredServices {
            
            if  let index =  service.characteristics?.index(of : characteristic),
                let characteristic = service.characteristics?[index] as? CBMutableCharacteristic
            {
                activeWriteTransaction?.characteristic = characteristic
            }
        }
        
        activeWriteTransations[centralUUID]?.append(activeWriteTransaction!)
        
        return activeWriteTransaction
    }
    
    
    /// Finds the local reference of the characteristic instance
    /// and sets the value once the transaction is complete.
    ///
    /// - Parameter transaction: compelted write trasaction
    internal func setLocalValue(for transaction : Transaction) {
        guard let characteristic = transaction.characteristic else {
             EBLog(.error, logString: "Could not Find Local Characteristic to Update")
            return
        }
        
        for service in registeredServices {
            if  let index =  service.characteristics?.index(of : characteristic),
                let characteristic = service.characteristics?[index] as? CBMutableCharacteristic {
                
                characteristic.value = transaction.data
            }
        }
    }
    
    
    /// Clears the write transation instance upon completion
    ///
    /// - Parameters:
    ///   - centralUUID: central initiating the transaction
    ///   - characteristic: characteristic written to
    internal func clearWriteTransaction(from centralUUID: UUID, on characteristic : CBCharacteristic) {
        if let index = self.activeWriteTransations[centralUUID]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeWriteTransations[centralUUID]?.remove(at: index)
        }
    }
}


// MARK: Read
extension EBPeripheralManager {
    
    /// Called by the peripheral manager delegate once a read request is
    /// received from the central
    ///
    /// - Parameter requests: request to process
    internal func handleReadRequest(_ request: CBATTRequest) {
    
        guard let centralIdentifier = request.central.value(forKey: "identifier") as? UUID,
              let responseData = processReadRequest(from: centralIdentifier,
                                                    for: request.characteristic,
                                                    mtuSize: Int16(request.central.maximumUpdateValueLength)) else {
                                                        return
        }
        
        request.value = responseData
        peripheralManager.respond(to: request, withResult: .success)
    }
    
    
    /// Called my by the delegate for a successful to preocess and respond to a request.
    /// This method gets called to request the next packet to send to the peripheral.
    ///
    /// - Parameters:
    ///   - centralUUID: central uuid requesting the read
    ///   - characteristic: characteristic beign requested
    ///   - mtuSize: synchronized mtu value from connection
    /// - Returns: data packet to send to the central
    internal func processReadRequest(from centralUUID : UUID,
                                     for characteristic: CBCharacteristic,
                                     mtuSize : Int16) -> Data? {
        
        guard let data = getLocalValue(for : characteristic),
            let activeReadTransaction = readTransaction(data, for: characteristic,
                                                        from: centralUUID,
                                                        mtuSize: mtuSize) else {
                                                            return nil
        }
        
        activeReadTransaction.processTransaction()
        
         EBLog(.debug, logString: "Peripheral Sent Read Packet \(activeReadTransaction.activeResponseCount) / \( activeReadTransaction.totalPackets)")
        
        if activeReadTransaction.isComplete {
             EBLog(.debug, logString: "Peripheral Sent Read Complete")
            clearReadTransaction(from: centralUUID, on: characteristic)
        }
        
        return activeReadTransaction.nextPacket()
    }
    
    
    /// Generates a read transactions if there isn't one in the queue already,
    /// and stores it in the activeReadTransations dictionary. The transaction
    /// keeps track of the packets sent to the central, and until all of them
    /// are sent.
    ///
    /// - Parameters:
    ///   - data: full data to send
    ///   - characteristic: characteristic being requested
    ///   - centralUUID: central uuid requesting the write
    ///   - mtuSize: synchronized mtu value from connection
    /// - Returns:  new or existing write transaction instance for the operation
    internal func readTransaction(_ data : Data,
                                  for characteristic : CBCharacteristic,
                                  from centralUUID : UUID,
                                  mtuSize : Int16) -> Transaction? {
        
        var activeReadTransaction = activeReadTransations[centralUUID]?.first(where: { $0.characteristic?.uuid == characteristic.uuid })
        
        if activeReadTransaction != nil  {
            return activeReadTransaction
        }
        
        if activeReadTransations[centralUUID] == nil {
            activeReadTransations[centralUUID] = [Transaction]()
        }
        
        var transactionType : TransactionType = .read
        
        if let _  = packetBasedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .readPackets
        }
        
        activeReadTransaction = Transaction(transactionType, .peripheralToCentral, mtuSize: mtuSize)
        
        for service in registeredServices {
            
            if  let index =  service.characteristics?.index(of : characteristic),
                let characteristic = service.characteristics?[index] as? CBMutableCharacteristic
            {
                activeReadTransaction?.characteristic = characteristic
            }
        }
        
        activeReadTransaction?.data = data
        activeReadTransations[centralUUID]?.append(activeReadTransaction!)
        
        return activeReadTransaction
    }
    
    
    /// Finds the local reference of the characteristic instance
    /// and returns the value to send to the central.
    ///
    /// - Parameter characteristic: characteristic requested
    /// - Returns: value to send to the central requesting it
    internal func getLocalValue(for characteristic: CBCharacteristic?) -> Data? {
        
        guard let characteristic = characteristic  else {
            return nil
        }
        
        for service in registeredServices {
            if let index =  service.characteristics?.index(of : characteristic),
                let data = (service.characteristics![index] as! CBMutableCharacteristic).value {
                return data
            }
        }
        
        return nil
    }
    
    
    /// Clears the read transation instance upon completion
    ///
    /// - Parameters:
    ///   - centralUUID: central initiating the transaction
    ///   - characteristic: characteristic written to
    internal func clearReadTransaction(from centralUUID: UUID, on characteristic : CBCharacteristic) {
        if let index = self.activeReadTransations[centralUUID]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeReadTransations[centralUUID]?.remove(at: index)
        }
    }
}


// MARK: Synchronization Handlers
extension EBPeripheralManager {
    
    internal func handleStateChange(on peripheral: CBPeripheralManager) {
        
        switch peripheral.state {
        case .poweredOn:
            if advertisingRequested {
                advertisingRequested = false
                startAdvertising()
            }
        default:
            break
        }
        
         EBLog(.debug, logString: "Peripheral BLE state - \(peripheral.state.rawValue)")
        stateChangeCallBack?(EBManagerState(rawValue: peripheral.state.rawValue)!)
    }
    
    internal func handleSubscription(for central: CBCentral, on characteristic: CBCharacteristic) {
        if let centralIdentifier = central.value(forKey: "identifier") as? UUID {
             EBLog(.debug, logString: "Central \(centralIdentifier)")
        }
        
         EBLog(.debug, logString: "    - Subscribed tp \(characteristic.uuid.uuidString)")
        if characteristic.uuid.uuidString == mtuCharacteristicUUIDKey {
            processMTUSubscription(for: central)
        }
    }
    
    internal func handleUnSubscription(for central: CBCentral, on characteristic: CBCharacteristic) {
        if let centralIdentifier = central.value(forKey: "identifier") as? UUID {
             EBLog(.debug, logString: "Central \(centralIdentifier) Unsubscribed for \(characteristic.uuid.uuidString)")
            
        }
    }
    
    internal func processMTUSubscription(for central: CBCentral) {
        
        for service in registeredServices {
            if let characteristic =  service.characteristics?.first(where: {
                $0.uuid.uuidString == mtuCharacteristicUUIDKey }) as? CBMutableCharacteristic {
                
                let messageData = NSMutableData()
                messageData.appendInt16(Int16(central.maximumUpdateValueLength))
                characteristic.value = (messageData as Data)
                
                 EBLog(.debug, logString: "Peripheral Notified Central w/ MTU value: \(central.maximumUpdateValueLength)")
                
                peripheralManager.updateValue((messageData as Data), for:  characteristic, onSubscribedCentrals: [central])
            }
        }
    }
}

