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
