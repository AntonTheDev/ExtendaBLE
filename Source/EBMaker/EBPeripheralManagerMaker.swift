//
//  EBPeripheralManagerMaker.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public class EBPeripheralManagerMaker  {
    
    internal var queue: DispatchQueue?
    internal var services = [EBServiceMaker]()
    internal var localName : String?
    internal var stateChangeCallBack         : PeripheralManagerStateChangeCallBack?
    internal var didStartAdvertisingCallBack : PeripheralManagerDidStartAdvertisingCallBack?
    
    required public init(queue: DispatchQueue?) {
        self.queue = queue
    }
    
    internal func constructedPeripheralManager() -> EBPeripheralManager {
        
        let newPeripheralManager = EBPeripheralManager(queue: queue)
        
        newPeripheralManager.localName = localName
        
        for service in services {
            
            guard let constructedService = service.constructedService() else {
                continue
            }
            
            for (uuid, updateCallback) in service.characteristicUpdateCallbacks {
                newPeripheralManager.registeredCharacteristicCallbacks[uuid] = updateCallback
            }
            
            
            newPeripheralManager.registeredServices.append(constructedService)
            newPeripheralManager.packetBasedCharacteristicUUIDS += service.packetBasedCharacteristicUUIDS
        }
        
        if newPeripheralManager.packetBasedCharacteristicUUIDS.count > 0 {
            if let mtuService = newMTUService() {
                newPeripheralManager.registeredServices.append(mtuService)
            }
        }
        
        newPeripheralManager.stateChangeCallBack = stateChangeCallBack
        newPeripheralManager.didStartAdvertisingCallBack = didStartAdvertisingCallBack
        
        return newPeripheralManager
    }
    
    #if !os(tvOS)
    
    @discardableResult public func addService(_ uuid: String,
                                              service : (_ service : EBServiceMaker) -> Void) -> EBPeripheralManagerMaker {
        let newService = EBServiceMaker(uuid)
        services.append(newService)
        service(newService)
        return self
    }
    
    @discardableResult public func localName(_ localname : String) -> EBPeripheralManagerMaker {
        self.localName = localname
        return self
    }
    
    @discardableResult public func onStateChange(_ callback : @escaping PeripheralManagerStateChangeCallBack) -> EBPeripheralManagerMaker {
        stateChangeCallBack = callback
        return self
    }
    
    @discardableResult public func onDidStartAdvertising(_ callback : @escaping PeripheralManagerDidStartAdvertisingCallBack) -> EBPeripheralManagerMaker {
        didStartAdvertisingCallBack = callback
        return self
    }
    
    #endif
    
}
