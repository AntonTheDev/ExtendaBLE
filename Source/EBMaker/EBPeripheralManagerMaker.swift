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
    var localName : String?

    required public init(queue: DispatchQueue?) {
        self.queue = queue
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
