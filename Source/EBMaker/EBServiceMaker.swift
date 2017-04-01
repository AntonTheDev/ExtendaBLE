//
//  EBServiceMaker.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public let mtuServiceUUIDKey = "F80A41CA-8B71-47BE-8A92-E05BB5F1F862"
public let mtuCharacteristicUUIDKey = "37CD1740-6822-4D85-9AAF-C2378FDC4329"

func newMTUService() -> CBMutableService? {
    
    #if os(tvOS)
        return nil
    #else
        let mtuService = CBMutableService(type: CBUUID(string: mtuServiceUUIDKey), primary: true)
        let mtuCharacteristic =  CBMutableCharacteristic(type: CBUUID(string: mtuCharacteristicUUIDKey),
                                                         properties: [.notify, .read], value: nil,
                                                         permissions: [.readable])
        
        mtuService.characteristics = [mtuCharacteristic]
        return mtuService
    #endif
}

public class EBServiceMaker {
    
    var serviceUUID : String
    var primary : Bool
    
    var characteristics             = [EBCharacteristicMaker]()
    var chunkedCharacteristicUUIDS  = [CBUUID]()
    
    var characteristicUpdateCallbacks = [CBUUID : EBTransactionCallback]()
    
    required public init(_ uuid: String, primary isPrimary: Bool = true) {
        serviceUUID = uuid
        primary = isPrimary
    }
    
    @discardableResult public func addProperty(_ UUID: String) -> EBCharacteristicMaker {
        let characteristic = EBCharacteristicMaker(uuid : UUID)
        characteristics.append(characteristic)
        return characteristic
    }
    
    func constructedService() -> CBMutableService? {
        
        #if os(tvOS)
            return nil
        #else
            let newService = CBMutableService(type: CBUUID(string: serviceUUID), primary: primary)
        
            for characteristic in characteristics {
                
                guard let newCharacteristic = characteristic.constructedCharacteristic() else {
                    continue
                }
                
                if newService.characteristics != nil {
                    newService.characteristics!.append(newCharacteristic)
                } else {
                    newService.characteristics = [newCharacteristic]
                }
                
                #if os(OSX)
                    let characteristicUUID = newCharacteristic.uuid!
                #else
                    let characteristicUUID = newCharacteristic.uuid
                #endif
                
                characteristicUpdateCallbacks[characteristicUUID] = characteristic.updateCallback
                
                if characteristic.chunkingEnabled {
                    chunkedCharacteristicUUIDS.append(characteristicUUID)
                }
            }
            
            return newService
        #endif
    }
}
