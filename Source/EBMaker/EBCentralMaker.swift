//
//  EBCentralMaker.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public class EBCentralMaker {
    
    var queue: DispatchQueue?
    var services = [EBServiceMaker]()
    var peripheralName : String?
    
    required public init(queue: DispatchQueue?) {
        self.queue = queue
    }
    
    @discardableResult public func addService(_ uuid: String, primary isPrimary: Bool = true, service : (_ service : EBServiceMaker) -> Void) -> EBCentralMaker {
        let newService = EBServiceMaker(uuid, primary: isPrimary)
        services.append(newService)
        service(newService)
        return self
    }
    
    public func constructedCentralManager() -> EBCentralManager {
        
        let newCentralManager = EBCentralManager(queue: queue)
        
        for service in services {
        
            let constructedService = service.constructedService()
            
            for (uuid, updateCallback) in service.characteristicUpdateCallbacks {
                newCentralManager.registeredCharacteristicUpdateCallbacks[uuid] = updateCallback
            }

            newCentralManager.services.append(constructedService)
            newCentralManager.chunkedCharacteristicUUIDS += service.chunkedCharacteristicUUIDS
        }
        
        if  newCentralManager.chunkedCharacteristicUUIDS.count > 0 {
            newCentralManager.services.append(newMTUService())
        }

        return newCentralManager
    }
    
    @discardableResult public func peripheralName(_ peripheralName : String) -> EBCentralMaker {
        self.peripheralName = peripheralName
        return self
    }
}
