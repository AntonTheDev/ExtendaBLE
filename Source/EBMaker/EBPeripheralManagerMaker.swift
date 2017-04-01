//
//  EBPeripheralManagerMaker.swift
//  CameraApp
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

    required public init(queue: DispatchQueue?) {
        self.queue = queue
    }
    
    @discardableResult public func localName(_ localname : String) -> EBPeripheralManagerMaker {
        self.localName = localname
        return self
    }
    
    @discardableResult public func addService(_ uuid: String,
                                              primary isPrimary: Bool = true,
                                              service : (_ service : EBServiceMaker) -> Void) -> EBPeripheralManagerMaker
    {
        let newService = EBServiceMaker(uuid, primary: isPrimary)
        services.append(newService)
        service(newService)
        return self
    }
    
    public func constructedPeripheralManager() -> EBPeripheralManager {
        
        let newPeripheralManager = EBPeripheralManager(queue: queue)

        newPeripheralManager.localName = localName
       
        for service in services {
            
            guard let constructedService = service.constructedService() else {
                continue
            }
        
            for (uuid, updateCallback) in service.characteristicUpdateCallbacks {
                newPeripheralManager.registeredCharacteristicUpdateCallbacks[uuid] = updateCallback
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
}
