//
//  EBPeripheralManagerMaker.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

extension ExtendaBLE {
    
    #if !os(tvOS)
    public class func newPeripheralManager(queue: DispatchQueue? = nil, peripheral : (_ peripheral : EBPeripheralManagerMaker) -> Void) -> EBPeripheralManager {
        let newManager = EBPeripheralManagerMaker(queue: queue)
        peripheral(newManager)
        return newManager.constructedPeripheralManager()
    }
    #endif
}

public class EBPeripheralManagerMaker  {

    private var queue: DispatchQueue?
    private var services = [EBServiceMaker]()
    private var localName : String?

    required public init(queue: DispatchQueue?) {
        self.queue = queue
    }
        
    fileprivate func constructedPeripheralManager() -> EBPeripheralManager {
        
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
            newPeripheralManager.chunkedCharacteristicUUIDS += service.chunkedCharacteristicUUIDS
        }
       
        if newPeripheralManager.chunkedCharacteristicUUIDS.count > 0 {
            if let mtuService = newMTUService() {
                newPeripheralManager.registeredServices.append(mtuService)
            }
        }
        
        return newPeripheralManager
    }
    
#if !os(tvOS)
        @discardableResult public func localName(_ localname : String) -> EBPeripheralManagerMaker {
            self.localName = localname
            return self
        }
        
        @discardableResult public func addService(_ uuid: String,
                                                  service : (_ service : EBServiceMaker) -> Void) -> EBPeripheralManagerMaker {
            let newService = EBServiceMaker(uuid)
            services.append(newService)
            service(newService)
            return self
        }
#endif

}
