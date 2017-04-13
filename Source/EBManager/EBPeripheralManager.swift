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
    
    internal var peripheralManager : CBPeripheralManager
    internal var localName : String?
    
    internal var registeredServices                 = [CBMutableService]()
    internal var registeredCharacteristicCallbacks  = [CBUUID : EBTransactionCallback]()
    internal var chunkedCharacteristicUUIDS         = [CBUUID]()
    
    internal var activeWriteTransations             = [CBCentral : [Transaction]]()
    internal var activeReadTransations              = [CBCentral : [Transaction]]()
    
    internal var operationQueue                     = DispatchQueue(label: "PeripheralManagerQueue", qos: .default)
    internal var dataQueue                          = DispatchQueue(label: "PeripheralOperationQueue", qos: .userInitiated)
    
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
        
        let serviceUUIDs = registeredServices.map { $0.uuid }
        
        if serviceUUIDs.count > 0 {
            advertisementData[CBAdvertisementDataServiceUUIDsKey] = serviceUUIDs
        }
        
        peripheralManager.startAdvertising(advertisementData)
        
        return self
    }
    
    @discardableResult public func stopAdvertising() -> EBPeripheralManager {
        peripheralManager.stopAdvertising()
        return self
    }
    
    @discardableResult public func onStateChange(_ callback : @escaping PeripheralManagerStateChangeCallBack) -> EBPeripheralManager {
        stateChangeCallBack = callback
        return self
    }
    
    @discardableResult public func onDidStartAdvertising(_ callback : @escaping PeripheralManagerDidStartAdvertisingCallBack) -> EBPeripheralManager {
        didStartAdvertisingCallBack = callback
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
        dataQueue.async { [unowned self] in
            self.handleReadRequest(request)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        dataQueue.async { [unowned self] in
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
        
        guard let data = localValue(for : request.characteristic) else {
            peripheralManager.respond(to: request, withResult: .attributeNotFound)
            return
        }
        
        guard let activeReadTransaction = readTransaction(data, for: request.characteristic, from: request.central) else {
            return
        }
        
        activeReadTransaction.processTransaction()
        request.value = activeReadTransaction.nextPacket()
        
        peripheralManager.respond(to: request, withResult: .success)
        
        Log(.debug, logString: "Peripheral Sent Read Packet \(activeReadTransaction.activeResponseCount) / \( activeReadTransaction.totalPackets)")
        
        if activeReadTransaction.isComplete {
            Log(.debug, logString: "Peripheral Sent Read Complete")
            clearReadTransaction(from: request.central, on: request.characteristic)
        }
    }
    
    internal func handleWriteRequests(_ requests: [CBATTRequest]) {
        
        for request in requests {
            
            guard let activeWriteTransaction = writeTransaction(for: request.characteristic, from: request.central) else {
                continue
            }
            
            activeWriteTransaction.appendPacket(request.value)
            activeWriteTransaction.processTransaction()
            
            Log(.debug, logString: "Peripheral Received Write Packet \(activeWriteTransaction.activeResponseCount) / \(activeWriteTransaction.totalPackets)")
            
            peripheralManager.respond(to: request, withResult: .success)
            
            if activeWriteTransaction.isComplete {
                Log(.debug, logString: "Peripheral Received Write Complete")
                
                finalizeLocalValue(for: activeWriteTransaction)
                registeredCharacteristicCallbacks[request.characteristic.uuid]?(activeWriteTransaction.data, nil)
                clearWriteTransaction(from: request.central, on: request.characteristic)
            }
        }
    }
    
    internal func handleSubscription(for central: CBCentral, on characteristic: CBCharacteristic) {
        Log(.debug, logString: "Central \(central.identifier) Subscribed tp \(characteristic.uuid.uuidString)")
        
        if characteristic.uuid.uuidString == mtuCharacteristicUUIDKey {
            processMTUSubscription(for: central)
        }
    }
    
    internal func handleUnSubscription(for central: CBCentral, on characteristic: CBCharacteristic) {
        Log(.debug, logString: "Central \(central.identifier) Unsubscribed for \(characteristic.uuid.uuidString)")
    }
    
    internal func processMTUSubscription(for central: CBCentral) {
        for service in registeredServices {
            
            if let characteristic =  service.characteristics?.first(where: { $0.uuid.uuidString == mtuCharacteristicUUIDKey }) as? CBMutableCharacteristic {
                
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
    
    internal func writeTransaction(for characteristic : CBCharacteristic,
                                   from central : CBCentral) -> Transaction? {
        
        var activeWriteTransaction = activeWriteTransations[central]?.first(where: { $0.characteristic?.uuid == characteristic.uuid })
        
        if activeWriteTransaction != nil  {
            return activeWriteTransaction
        }
        
        if activeWriteTransations[central] == nil {
            activeWriteTransations[central] = [Transaction]()
        }
        
        var transactionType : TransactionType = .write
        
        if let _  = chunkedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .writeChunkable
        }
        
        activeWriteTransaction = Transaction(transactionType, .peripheralToCentral, mtuSize: Int16(central.maximumUpdateValueLength))
        
        for service in registeredServices {
            
            if  let index =  service.characteristics?.index(of : characteristic),
                let characteristic = service.characteristics?[index] as? CBMutableCharacteristic
            {
                activeWriteTransaction?.characteristic = characteristic
            }
        }
        
        activeWriteTransations[central]?.append(activeWriteTransaction!)
        
        return activeWriteTransaction
    }
    
    internal func readTransaction(_ data : Data,
                                  for characteristic : CBCharacteristic,
                                  from central : CBCentral) -> Transaction? {
        
        var activeReadTransaction = activeReadTransations[central]?.first(where: { $0.characteristic?.uuid == characteristic.uuid })
        
        if activeReadTransaction != nil  {
            return activeReadTransaction
        }
        
        if activeReadTransations[central] == nil {
            activeReadTransations[central] = [Transaction]()
        }
        
        var transactionType : TransactionType = .read
        
        if let _  = chunkedCharacteristicUUIDS.first(where: { $0 == characteristic.uuid }) {
            transactionType = .readChunkable
        }
        
        activeReadTransaction = Transaction(transactionType, .peripheralToCentral, mtuSize:  Int16(central.maximumUpdateValueLength))
        
        for service in registeredServices {
            
            if  let index =  service.characteristics?.index(of : characteristic),
                let characteristic = service.characteristics?[index] as? CBMutableCharacteristic
            {
                activeReadTransaction?.characteristic = characteristic
            }
        }
        
        activeReadTransaction?.data = data
        
        activeReadTransations[central]?.append(activeReadTransaction!)
        
        return activeReadTransaction
    }
    
    internal func localValue(for characteristic: CBCharacteristic?) -> Data? {
        
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

    internal func clearReadTransaction(from central: CBCentral, on characteristic : CBCharacteristic) {
        if let index = self.activeReadTransations[central]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeReadTransations[central]?.remove(at: index)
        }
    }
    
    internal func clearWriteTransaction(from central: CBCentral, on characteristic : CBCharacteristic) {
        if let index = self.activeWriteTransations[central]?.index(where: {
            $0.characteristic?.uuid.uuidString.uppercased() == characteristic.uuid.uuidString.uppercased() })
        {
            activeWriteTransations[central]?.remove(at: index)
        }
    }
    
    internal func finalizeLocalValue(for transaction : Transaction) {
        
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
}

