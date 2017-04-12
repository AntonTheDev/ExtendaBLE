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
    internal var registeredServices = [CBMutableService]()
    
    internal var chunkedCharacteristicUUIDS = [CBUUID]()
    internal var registeredCharacteristicUpdateCallbacks = [CBUUID : EBTransactionCallback]()

    internal var activeWriteTransations = [CBCentral : [Transaction]]()
    internal var activeReadTransations = [CBCentral : [Transaction]]()
    
    internal var stateChangeCallBack : PeripheralManagerStateChangeCallBack?
    internal var didStartAdvertisingCallBack : PeripheralManagerDidStartAdvertisingCallBack?
    internal var didAddServiceCallBack : PeripheralManagerDidAddServiceCallBack?
    internal var subscriptionChangeCallBack : PeripheralManagerSubscriopnChangeToCallBack?
    internal var readyToUpdateSubscribersCallBack : PeripheralManagerIsReadyToUpdateCallBack?
    
    internal var defaultQueue = DispatchQueue(label: "CentralManagerQueue", qos: .default)
    internal var dataQueue = DispatchQueue(label: "DataOperationQueue", qos: .userInitiated)
    
    
    @available(iOS 9.0, OSX 10.10, *)
    public required init(queue: DispatchQueue?) {
        #if os(tvOS)
            peripheralManager = CBPeripheralManager()
        #else
            peripheralManager = CBPeripheralManager(delegate: nil, queue: queue != nil ? queue : defaultQueue)
        #endif
        
        super.init()
        peripheralManager.delegate = self
    }
}

extension EBPeripheralManager {
    
    @discardableResult public func startAdvertising() -> EBPeripheralManager {
        
        if peripheralManager.state != .poweredOn {
            return self
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
    
    internal func configureServices() {
        for service in registeredServices {
            peripheralManager.add(service)
        }
    }
    
    internal func clearServices() {
        for service in registeredServices {
            peripheralManager.remove(service)
        }
    }
}


// MARK: - Recursive Delegate Callback Setters

extension EBPeripheralManager {
    
    @discardableResult public func onStateChange(_ callback : @escaping PeripheralManagerStateChangeCallBack) -> EBPeripheralManager {
        stateChangeCallBack = callback
        return self
    }
    
    @discardableResult public func onDidStartAdvertising(_ callback : @escaping PeripheralManagerDidStartAdvertisingCallBack) -> EBPeripheralManager {
        didStartAdvertisingCallBack = callback
        return self
    }
    
    @discardableResult public func onDidAddService(_ callback : @escaping PeripheralManagerDidAddServiceCallBack) -> EBPeripheralManager {
        didAddServiceCallBack = callback
        return self
    }
    
    @discardableResult public func onSubscriptionChange(_ callback : @escaping PeripheralManagerSubscriopnChangeToCallBack) -> EBPeripheralManager {
        subscriptionChangeCallBack = callback
        return self
    }
    
    @discardableResult public func onReadyToUpdateSubscribers(_ callback : @escaping PeripheralManagerIsReadyToUpdateCallBack) -> EBPeripheralManager {
        readyToUpdateSubscribersCallBack = callback
        return self
    }
}


// MARK: - CBPeripheralManagerDelegate

extension EBPeripheralManager: CBPeripheralManagerDelegate {
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            configureServices()
            startAdvertising()
        default:
            break
        }
        
        print("\nPeripheral BLE state - \(peripheral.state.rawValue)")
        stateChangeCallBack?(EBManagerState(rawValue: peripheral.state.rawValue)!)
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("\nStarted Advertising - Error: \(String(describing: error))\n")
        didStartAdvertisingCallBack?((error != nil ? false : true), error)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        print("\nAdded Service \(service.uuid.uuidString) - Error: \(String(describing: error))")
        didAddServiceCallBack?(service, error)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        handleReadRequest(request)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        handleWriteRequests(requests)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central MTU : ", central.maximumUpdateValueLength, "\n")
        
        handleMTUSubscription(for: central)
        subscriptionChangeCallBack?(true, central, characteristic)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscriptionChangeCallBack?(false, central, characteristic)
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("onReadyToUpdateSubscribers")
        readyToUpdateSubscribersCallBack?()
    }
}

// MARK: Transaction Handlers

extension EBPeripheralManager {
    
    internal func handleReadRequest(_ request: CBATTRequest) {
        
        guard let data = dataValue(for : request.characteristic) else {
            peripheralManager.respond(to: request, withResult: .attributeNotFound)
            return
        }
        
        let triggerBlock = { (activeReadTransaction : Transaction)-> () in
            
            activeReadTransaction.sentReceipt()
            request.value = activeReadTransaction.nextPacket()
            
            self.peripheralManager.respond(to: request, withResult: .success)
            
            print("Peripheral Read Packet ", activeReadTransaction.activeResponseCount, " / ",  activeReadTransaction.totalPackets)
            
            if activeReadTransaction.isComplete {
                print("Peripheral Read Complete")
                
                if let index = self.activeReadTransations[request.central]?.index(where: { $0.characteristic == request.characteristic }) {
                    self.activeReadTransations[request.central]?.remove(at: index)
                }
                
                return
            }
        }
        
        if let activeReadTransaction = activeReadTransations[request.central]?.first(where: { $0.characteristic == request.characteristic }) {
            triggerBlock(activeReadTransaction)
        } else {
            
            if activeReadTransations[request.central] == nil {
                activeReadTransations[request.central] = [Transaction]()
            }
            
            var transactionType : TransactionType = .read
            
            if let _  = chunkedCharacteristicUUIDS.first(where: { $0 == request.characteristic.uuid }) {
                transactionType = .readChunkable
            }
            
            let activeReadTransaction = Transaction(transactionType, .peripheralToCentral, mtuSize:  Int16(request.central.maximumUpdateValueLength))
            activeReadTransaction.data = data
            activeReadTransaction.characteristic = characteristic(for: request)
            
            activeReadTransations[request.central]?.append(activeReadTransaction)
            triggerBlock(activeReadTransaction)
        }
    }
    
    internal func handleWriteRequests(_ requests: [CBATTRequest]) {
        
        let triggerBlock = { [weak self] (_ writeTransaction : Transaction, _ request: CBATTRequest)-> ()  in
            
            writeTransaction.appendPacket(request.value)
            writeTransaction.sentReceipt()
            
            print("Peripheral Write Packet ", writeTransaction.activeResponseCount, " / ",  writeTransaction.totalPackets)
            
            if let characteristic = self?.characteristic(for : request) {
                self?.peripheralManager.respond(to: request, withResult: .success)
                
                if writeTransaction.isComplete {
                    
                    print("Peripheral Write Complete")
                    characteristic.value = writeTransaction.data
                    
                    if let index = self?.activeWriteTransations[request.central]?.index(where: { $0.characteristic == request.characteristic }) {
                        self?.activeWriteTransations[request.central]?.remove(at: index)
                    }
                    
                    self?.registeredCharacteristicUpdateCallbacks[request.characteristic.uuid]?(writeTransaction.data, nil)
                }
            }
        }
        
        for request in requests {
            
            var activeWriteTransaction = activeWriteTransations[request.central]?.first(where: { $0.characteristic?.uuid == request.characteristic.uuid })
            
            if activeWriteTransaction != nil  {
                triggerBlock(activeWriteTransaction!, request)
            } else {
                
                if activeWriteTransations[request.central] == nil {
                    activeWriteTransations[request.central] = [Transaction]()
                }
                
                var transactionType : TransactionType = .write
                
                if let _  = chunkedCharacteristicUUIDS.first(where: { $0 == request.characteristic.uuid }) {
                    transactionType = .writeChunkable
                }
                
                activeWriteTransaction = Transaction(transactionType, .peripheralToCentral, mtuSize: Int16(request.central.maximumUpdateValueLength))
                activeWriteTransaction?.characteristic = characteristic(for: request)
                activeWriteTransations[request.central]?.append(activeWriteTransaction!)
                triggerBlock(activeWriteTransaction!, request)
            }
        }
    }
    
    internal func handleMTUSubscription(for central: CBCentral) {
        
        for service in registeredServices {
            if let characteristic =  service.characteristics?.first(where: { $0.uuid.uuidString == mtuCharacteristicUUIDKey }) as? CBMutableCharacteristic {
                let messageData = NSMutableData()
                messageData.appendInt16(Int16(central.maximumUpdateValueLength))
                characteristic.value = (messageData as Data)
                
                peripheralManager.updateValue((messageData as Data), for:  characteristic, onSubscribedCentrals: [central])
            }
        }
    }
    
    internal func dataValue(for characteristic: CBCharacteristic?) -> Data? {
        
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
    
    internal func characteristic(for request: CBATTRequest) -> CBMutableCharacteristic? {
        
        for service in registeredServices {
            if  let index =  service.characteristics?.index(of : request.characteristic),
                let characteristic = service.characteristics?[index] as? CBMutableCharacteristic {
                return characteristic
            }
        }
        
        return nil
    }
}

