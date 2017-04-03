//
//  EBPeripheral.swift
//  CameraApp
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
    
    internal var mtuValue : Int16 = 23
    
    internal var registeredServices = [CBMutableService]()
    
    internal var chunkedCharacteristicUUIDS = [CBUUID]()
    internal var registeredCharacteristicUpdateCallbacks = [CBUUID : EBTransactionCallback]()
    
    internal var activeWriteTransations = [CBUUID : Transaction]()
    internal var activeReadTransations = [CBUUID : Transaction]()
    
    internal var stateChangeCallBack : PeripheralManagerStateChangeCallBack?
    internal var didStartAdvertisingCallBack : PeripheralManagerDidStartAdvertisingCallBack?
    internal var didAddServiceCallBack : PeripheralManagerDidAddServiceCallBack?
    internal var subscriptionChangeCallBack : PeripheralManagerSubscriopnChangeToCallBack?
    internal var readyToUpdateSubscribersCallBack : PeripheralManagerIsReadyToUpdateCallBack?
    
    @available(iOS 9.0, OSX 10.10, *)
    public required init(queue: DispatchQueue?) {
        #if os(tvOS)
            peripheralManager = CBPeripheralManager()
        #else
            peripheralManager = CBPeripheralManager(delegate: nil, queue: queue)
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

// MARK: Transaction Handlers

extension EBPeripheralManager {
    
    internal func handleReadRequest(_ request: CBATTRequest) {
        
        guard let data = dataValue(for : request.characteristic) else {
            peripheralManager.respond(to: request, withResult: .attributeNotFound)
            return
        }
        
        var activeReadTransaction = activeReadTransations[request.characteristic.uuid]
        
        if activeReadTransaction == nil {
            
            var transactionType : TransactionType = .read
            
            if let _  = chunkedCharacteristicUUIDS.first(where: { $0 == request.characteristic.uuid }) {
                transactionType = .readChunkable
            }
            
            activeReadTransaction = Transaction(transactionType, .peripheralToCentral, mtuSize:  mtuValue)
            activeReadTransaction?.data = data
            activeReadTransaction?.characteristic = characteristic(for: request)
            
            activeReadTransations[request.characteristic.uuid] = activeReadTransaction
        }
        
        guard let readTransaction = activeReadTransations[request.characteristic.uuid] else {
            return
        }
        
        readTransaction.sentReceipt()
        request.value = readTransaction.nextPacket()
        peripheralManager.respond(to: request, withResult: .success)
        
        if readTransaction.isComplete {
            activeReadTransations[request.characteristic.uuid] = nil
            //registeredCharacteristicReadCallbacks[request.characteristic.uuid]?(readTransaction.data!)
        }
    }
    
    internal func handleWriteRequests(_ requests: [CBATTRequest]) {
        
        for request in requests {
            
            var activeWriteTransaction = activeWriteTransations[request.characteristic.uuid]
            
            if activeWriteTransaction == nil {
                
                var transactionType : TransactionType = .write
                
                if let _  = chunkedCharacteristicUUIDS.first(where: { $0 == request.characteristic.uuid }) {
                    transactionType = .writeChunkable
                }
                
                activeWriteTransaction = Transaction(transactionType, .peripheralToCentral, mtuSize:  mtuValue)
                activeWriteTransaction?.characteristic = characteristic(for: request)
                activeWriteTransations[request.characteristic.uuid] = activeWriteTransaction
            }
            
            guard let writeTransaction = activeWriteTransations[request.characteristic.uuid] else {
                return
            }
            
            writeTransaction.appendPacket(request.value)
            writeTransaction.sentReceipt()
            
            if let characteristic = characteristic(for : request) {
                
                peripheralManager.respond(to: request, withResult: .success)
                
                if writeTransaction.isComplete {
                    characteristic.value = writeTransaction.data
                    
                    activeWriteTransations[request.characteristic.uuid] = nil
                    registeredCharacteristicUpdateCallbacks[request.characteristic.uuid]?(writeTransaction.data, nil)
                }
            }
        }
    }
    
    internal func handleMTUSubscription(for central: CBCentral) {
        for service in registeredServices {
            if let characteristic =  service.characteristics?.first(where: { $0.uuid.uuidString == mtuCharacteristicUUIDKey }) as? CBMutableCharacteristic {
                
                var value: Int = central.maximumUpdateValueLength
                let data: Data =  NSData(bytes: &value, length: MemoryLayout<Int>.size) as Data
                
                mtuValue = Int16(value)
                peripheralManager.updateValue(data, for:  characteristic, onSubscribedCentrals: [central])
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
        if #available(iOS 10.0, *) {
            switch peripheral.state {
            case .poweredOn:
                configureServices()
                startAdvertising()
            default:
                break
            }
            
            print("\nPeripheral BLE state - \(peripheral.state.rawValue)")
            stateChangeCallBack?(EBManagerState(rawValue: peripheral.state.rawValue)!)
        } else {
            switch peripheral.state{
            case .poweredOn:
                 configureServices()
                startAdvertising()
            default:
                break
            }
            
            print("\nPeripheral BLE state - \(peripheral.state.rawValue)")
            stateChangeCallBack?(EBManagerState(rawValue: peripheral.state.rawValue)!)
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("\nStarted Advertising - \(String(describing: error))")
        didStartAdvertisingCallBack?((error != nil ? false : true), error)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        print("\nAdded Service \(service.uuid.uuidString) - \(String(describing: error))")
        didAddServiceCallBack?(service, error)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("didReceiveRead")
        handleReadRequest(request)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("didReceiveWrite")
        handleWriteRequests(requests)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
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
