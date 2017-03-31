//
//  EBPeripheralMaker.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public let mtuServiceUUIDKey = "F80A41CA-8B71-47BE-8A92-E05BB5F1F862"
public let mtuCharacteristicUUIDKey = "37CD1740-6822-4D85-9AAF-C2378FDC4329"

func newMTUService() -> CBMutableService {
    
    #if os(tvOS)
        let mtuService = CBService(type: CBUUID(string: mtuServiceUUIDKey), primary: true)
        let mtuCharacteristic =  CBCharacteristic(type: CBUUID(string: mtuCharacteristicUUIDKey), properties: [.notify, .read], value: nil, permissions: [.readable])
    #else
        let mtuService = CBMutableService(type: CBUUID(string: mtuServiceUUIDKey), primary: true)
        let mtuCharacteristic =  CBMutableCharacteristic(type: CBUUID(string: mtuCharacteristicUUIDKey), properties: [.notify, .read], value: nil, permissions: [.readable])
    #endif

    mtuService.characteristics = [mtuCharacteristic]
    return mtuService
}

public class EBPeripheralMaker {
    
    var queue: DispatchQueue?
    
    var localName : String?
    var services = [String : EBServiceMaker]()
    
    required public init(queue: DispatchQueue?) {
        self.queue = queue
    }

    public func constructedPeripheralManager() -> EBPeripheralManager {
        let newPeripheralManager = EBPeripheralManager(queue: queue)
       
        newPeripheralManager.localName = localName
       
        for (_, service) in services {
            
            let constructedService = service.constructedService()
        
            for (uuid, updateCallback) in service.characteristicUpdateCallbacks {
                newPeripheralManager.registeredCharacteristicUpdateCallbacks[uuid] = updateCallback
            }
            
            newPeripheralManager.services.append(constructedService)
            newPeripheralManager.chunkedCharacteristicUUIDS += service.chunkedCharacteristicUUIDS
        }
       
        if newPeripheralManager.chunkedCharacteristicUUIDS.count > 0 {
             newPeripheralManager.services.append(newMTUService())
        }
        
        return newPeripheralManager
    }
    
    @discardableResult public func addService(_ uuid: String, primary isPrimary: Bool = true, service : (_ service : EBServiceMaker) -> Void) -> EBPeripheralMaker {
        let newService = EBServiceMaker(uuid, primary: isPrimary)
        services[uuid] = newService
        service(newService)
        return self
    }

    @discardableResult public func localName(_ localname : String) -> EBPeripheralMaker {
        self.localName = localname
        return self
    }
}
