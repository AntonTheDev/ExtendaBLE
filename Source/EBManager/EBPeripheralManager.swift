//
//  EBPeripheral.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

public typealias PeripheralManagerStateChangeCallBack = ((_ state: CBManagerState) -> Void)
public typealias PeripheralManagerDidStartAdvertisingCallBack = ((_ started : Bool, _ error: Error?) -> Void)
public typealias PeripheralManagerDidAddServiceCallBack = ((_ service: CBService, _ error: Error?) -> Void)
public typealias PeripheralManagerSubscriopnChangeToCallBack = ((_ subscribed : Bool, _ central: CBCentral, _ characteristic: CBCharacteristic) -> Void)
public typealias PeripheralManagerIsReadyToUpdateCallBack = (() -> Void)

public class EBPeripheralManager : NSObject {
    
    internal var localName : String?
    internal var peripheralManager : CBPeripheralManager
    
    internal var mtuValue : Int16 = 0
    
    internal var services = [CBMutableService]()
    
    internal var registeredCharacteristicUpdateCallbacks = [CBUUID : EBTransactionCallback]()
    
    internal var activeWriteTransations = [CBUUID : Transaction]()
    internal var activeReadTransations = [CBUUID : Transaction]()
    
    internal var stateChangeCallBack : PeripheralManagerStateChangeCallBack?
    internal var didStartAdvertisingCallBack : PeripheralManagerDidStartAdvertisingCallBack?
    internal var didAddServiceCallBack : PeripheralManagerDidAddServiceCallBack?
    internal var subscriptionChangeCallBack : PeripheralManagerSubscriopnChangeToCallBack?
    internal var readyToUpdateSubscribersCallBack : PeripheralManagerIsReadyToUpdateCallBack?
    
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
        
        let serviceUUIDs = services.map { $0.uuid }
        
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
        for service in services {
            peripheralManager.add(service)
        }
    }
    
    internal func clearServices() {
        for service in services {
            peripheralManager.remove(service)
        }
    }
    
    internal func handleReadRequest(_ request: CBATTRequest) {

        if let readTransaction = readTransaction(for: request) {
            
            readTransaction.responseCount = readTransaction.responseCount  +  1

            request.value = readTransaction.chunks[readTransaction.responseCount - 1]

            peripheralManager.respond(to: request, withResult: .success)
            
            if readTransaction.isComplete {
                activeReadTransations[request.characteristic.uuid] = nil
                //registeredCharacteristicReadCallbacks[request.characteristic.uuid]?(readTransaction.data!)
            }
        }
    }
    
    internal func handleWriteRequests(_ requests: [CBATTRequest]) {
        
        for request in requests {
            if let characteristic = characteristic(for : request) {
                
                guard let  transaction = writeTransaction(for : request) else {
                    break
                }

                peripheralManager.respond(to: request, withResult: .success)
                
                if transaction.isComplete {
                    let reconstructedValue = transaction.reconstructedValue
                    characteristic.value = reconstructedValue
                    
                    activeWriteTransations[request.characteristic.uuid] = nil
                    registeredCharacteristicUpdateCallbacks[request.characteristic.uuid]?(reconstructedValue, nil)
                }
            }
        }
    }
    
    internal func handleMTUSubscription(for central: CBCentral) {
        for service in services {
            if let characteristic =  service.characteristics?.first(where: { $0.uuid.uuidString == mtuCharacteristicUUIDKey }) as? CBMutableCharacteristic {
                
                var value: Int = central.maximumUpdateValueLength
                let data: Data =  NSData(bytes: &value, length: MemoryLayout<Int>.size) as Data
                
                mtuValue = Int16(value)
                peripheralManager.updateValue(data, for:  characteristic, onSubscribedCentrals: [central])
            }
        }
    }
}


// MARK: Transaction Handlers

extension EBPeripheralManager {
    
    internal func readTransaction(for request: CBATTRequest) ->Transaction? {
        
        if let data = dataValue(for : request.characteristic) {
            
            var readTransaction = activeReadTransations[request.characteristic.uuid]
        
            if readTransaction == nil {
                readTransaction = Transaction()
                readTransaction?.data = data
                readTransaction?.chunks = data.packetArray(withMTUSize: mtuValue)
                activeReadTransations[request.characteristic.uuid] = readTransaction
            }
            
            return readTransaction
        }
        
        return nil
    }
    
    internal func writeTransaction(for request: CBATTRequest) -> Transaction? {
        
        if let data = request.value {
            
            var writeTransaction = activeWriteTransations[request.characteristic.uuid]
            
            if writeTransaction == nil {
                writeTransaction = Transaction()
                writeTransaction!.responseCount = data.totalPackets
                activeWriteTransations[request.characteristic.uuid] = writeTransaction
            }
            
            writeTransaction!.chunks.append(data)
            
            return writeTransaction
        }
        
        return nil
    }
    
    internal func dataValue(for characteristic: CBCharacteristic?) -> Data? {
        
        guard let characteristic = characteristic  else {
            return nil
        }
        
        for service in services {
            
            if let index =  service.characteristics?.index(of : characteristic),
                let data = (service.characteristics![index] as! CBMutableCharacteristic).value {
                
                return data
            }
        }
        
        return nil
    }
    
    internal func characteristic(for request: CBATTRequest) -> CBMutableCharacteristic? {
        
        for service in services {
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
        
        switch peripheral.state {
        case .poweredOn:
            configureServices()
            startAdvertising()
        default:
            break;
        }
        
        print("\nPeripheral \(UIDevice.current.name) BLE state - \(peripheral.state.rawValue)")
        stateChangeCallBack?(peripheral.state)
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
