//
//  EBCentralManagerMaker.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public class EBCentralManagerMaker  {
    
    internal var queue: DispatchQueue?
    internal var services = [EBServiceMaker]()
    internal var peripheralName : String?
    
    required public init(queue: DispatchQueue?) {
        self.queue = queue
    }
    
    @discardableResult public func peripheralName(_ peripheralName : String) -> EBCentralManagerMaker {
        self.peripheralName = peripheralName
        return self
    }
    
    @discardableResult public func addService(_ uuid: String,
                                              primary isPrimary: Bool = true,
                                              service : (_ service : EBServiceMaker) -> Void) -> EBCentralManagerMaker
    {
        let newService = EBServiceMaker(uuid, primary: isPrimary)
        services.append(newService)
        service(newService)
        return self
    }
    
    public func constructedCentralManager() -> EBCentralManager {
        
        let newCentralManager = EBCentralManager(queue: queue)
        
        for service in services {
            for (uuid, updateCallback) in service.characteristicUpdateCallbacks {
                newCentralManager.registeredCharacteristicUpdateCallbacks[uuid] = updateCallback
            }

            newCentralManager.registeredServiceUUIDs.append(CBUUID(string: service.serviceUUID))
            newCentralManager.chunkedCharacteristicUUIDS += service.chunkedCharacteristicUUIDS
        }
        
        if  newCentralManager.chunkedCharacteristicUUIDS.count > 0 {
            newCentralManager.registeredServiceUUIDs.append(CBUUID(string: mtuServiceUUIDKey))
        }

        return newCentralManager
    }
}
