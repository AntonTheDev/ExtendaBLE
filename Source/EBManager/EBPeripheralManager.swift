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
    
    internal var peripheralManager                  : CBPeripheralManager
    internal var localName                          : String?
    
    internal var registeredServices                 = [CBMutableService]()
    internal var registeredCharacteristicCallbacks  = [CBUUID : EBTransactionCallback]()
    internal var packetBasedCharacteristicUUIDS     = [CBUUID]()
    
    internal var activeWriteTransations             = [UUID : [Transaction]]()
    internal var activeReadTransations              = [UUID : [Transaction]]()
    
    internal var operationQueue                     = DispatchQueue(label: "PeripheralManagerQueue", qos: .userInitiated)
    internal var dataQueue                          = DispatchQueue(label: "PeripheralOperationQueue", qos: .default )

    internal var stateChangeCallBack                : PeripheralManagerStateChangeCallBack?
    internal var didStartAdvertisingCallBack        : PeripheralManagerDidStartAdvertisingCallBack?
    
    internal var advertisingRequested : Bool        = false
    
    @available(iOS 9.0, OSX 10.10, *)
    public required init(queue: DispatchQueue?) {
        #if os(tvOS)
            peripheralManager = CBPeripheralManager()
        #else
            peripheralManager = CBPeripheralManager(delegate: nil, queue: queue != nil ? queue : operationQueue)
        #endif
        
        super.init()
        peripheralManager.delegate = self
    }
}

extension EBPeripheralManager {
    
    @discardableResult public func startAdvertising() -> EBPeripheralManager {
        
        if peripheralManager.state != .poweredOn {
            peripheralManager.delegate = self
            advertisingRequested = true
            return self
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
        advertisementData[CBAdvertisementDataServiceUUIDsKey] = uuid // registeredServices.filter { $0.isPrimary }.map { $0.uuid }
        
        peripheralManager.startAdvertising(advertisementData)
        
        return self
    }
    
    @discardableResult public func stopAdvertising() -> EBPeripheralManager {
        peripheralManager.stopAdvertising()
        return self
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
        Log(.debug, logString: "Started Advertising - Error: \(String(describing: error))")
        didStartAdvertisingCallBack?((error != nil ? false : true), error)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        Log(.debug, logString: "Added Service \(service.uuid.uuidString) - Error: \(String(describing: error))")
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        Log(.debug, logString: "onReadyToUpdateSubscribers")
    }
}


// MARK: Transaction Handlers

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
        
        Log(.debug, logString: "Peripheral BLE state - \(peripheral.state.rawValue)")
        stateChangeCallBack?(EBManagerState(rawValue: peripheral.state.rawValue)!)
    }
    
    internal func handleReadRequest(_ request: CBATTRequest) {
    
        guard let responseData = processReadRequest(from: request.central.identifier,
                                                    for: request.characteristic,
                                                    mtuSize: Int16(request.central.maximumUpdateValueLength)) else {
            return
        }
        
        request.value = responseData
        peripheralManager.respond(to: request, withResult: .success)
    }
    
    internal func handleWriteRequests(_ requests: [CBATTRequest]) {
        
        for request in requests {
            if processWriteRequest(packet: request.value,
                                   from: request.central.identifier,
                                   for: request.characteristic,
                                   mtuSize: Int16(request.central.maximumUpdateValueLength)) {
                
                peripheralManager.respond(to: request, withResult: .success)
  
                if activeWriteTransations[request.central.identifier]?
                    .first(where: { $0.characteristic?.uuid == request.characteristic.uuid }) == nil {
                     processMTUSubscription(for: request.central)
                }
            }
        }
    }
    
    // TODO: Test This Method
    internal func processReadRequest(from centralUUID : UUID, for characteristic: CBCharacteristic, mtuSize : Int16) -> Data? {
        
        guard let data = getLocalValue(for : characteristic),
              let activeReadTransaction = readTransaction(data, for: characteristic,
                                                          from: centralUUID,
                                                          mtuSize: mtuSize) else {
                                                            return nil
        }
        
        activeReadTransaction.processTransaction()
        
        Log(.debug, logString: "Peripheral Sent Read Packet \(activeReadTransaction.activeResponseCount) / \( activeReadTransaction.totalPackets)")
        
        if activeReadTransaction.isComplete {
            Log(.debug, logString: "Peripheral Sent Read Complete")
            clearReadTransaction(from: centralUUID, on: characteristic)
        }
        
        return activeReadTransaction.nextPacket()
    }
    
    // TODO: Test This Method
    internal func processWriteRequest(packet : Data?, from centralUUID : UUID, for characteristic: CBCharacteristic, mtuSize : Int16) -> Bool {
        
        guard let activeWriteTransaction = writeTransaction(for: characteristic,
                                                            from: centralUUID,
                                                            mtuSize: mtuSize) else {
            return false
        }
        
        activeWriteTransaction.appendPacket(packet)
        activeWriteTransaction.processTransaction()
        
        Log(.debug, logString: "Peripheral Received Write Packet \(activeWriteTransaction.activeResponseCount) / \(activeWriteTransaction.totalPackets)")
        
        if activeWriteTransaction.isComplete {
            Log(.debug, logString: "Peripheral Received Write Complete")
            
            setLocalValue(for: activeWriteTransaction)
            registeredCharacteristicCallbacks[characteristic.uuid]?(activeWriteTransaction.data, nil)
            clearWriteTransaction(from: centralUUID, on: characteristic)
    
        }
        
        return true

    }
}

extension EBPeripheralManager {
    
    internal func handleSubscription(for central: CBCentral, on characteristic: CBCharacteristic) {
        Log(.debug, logString: "Central \(central.identifier)")
        Log(.debug, logString: "    - Subscribed tp \(characteristic.uuid.uuidString)")
        if characteristic.uuid.uuidString == mtuCharacteristicUUIDKey {
            processMTUSubscription(for: central)
        }
    }
    
    internal func handleUnSubscription(for central: CBCentral, on characteristic: CBCharacteristic) {
        Log(.debug, logString: "Central \(central.identifier) Unsubscribed for \(characteristic.uuid.uuidString)")
    }
    
    internal func processMTUSubscription(for central: CBCentral) {
        
        for service in registeredServices {
            if let characteristic =  service.characteristics?.first(where: {
                $0.uuid.uuidString == mtuCharacteristicUUIDKey }) as? CBMutableCharacteristic {
                
                let messageData = NSMutableData()
                messageData.appendInt16(Int16(central.maximumUpdateValueLength))
                characteristic.value = (messageData as Data)
                
                Log(.debug, logString: "Peripheral Notified Central w/ MTU value: \(central.maximumUpdateValueLength)")
                
                peripheralManager.updateValue((messageData as Data), for:  characteristic, onSubscribedCentrals: [central])
            }
        }
    }
}

extension EBPeripheralManager {
    
    // TODO: Test This Method
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
    
    // TODO: Test This Method
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
    

    // TODO: Test This Method
    internal func clearReadTransaction(from centralUUID: UUID, on characteristic : CBCharacteristic) {
        if let index = self.activeReadTransations[centralUUID]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeReadTransations[centralUUID]?.remove(at: index)
        }
    }
    
    // TODO: Test This Method
    internal func clearWriteTransaction(from centralUUID: UUID, on characteristic : CBCharacteristic) {
        if let index = self.activeWriteTransations[centralUUID]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeWriteTransations[centralUUID]?.remove(at: index)
        }
    }
    
    internal func setLocalValue(for transaction : Transaction) {
        
        guard let characteristic = transaction.characteristic else {
            Log(.error, logString: "Could not Find Local Characteristic to Update")
            return
        }
        
        for service in registeredServices {
            if  let index =  service.characteristics?.index(of : characteristic),
                let characteristic = service.characteristics?[index] as? CBMutableCharacteristic {
                
                characteristic.value = transaction.data
            }
        }
    }
    
    // TODO: Test This Method
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
}

