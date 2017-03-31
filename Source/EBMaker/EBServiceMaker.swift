//
//  EBServiceMaker.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public class EBServiceMaker {
    
    var serviceUUID : String
    var primary : Bool
    
    var characteristics = [EBCharacteristicMaker]()
    
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
   
    func constructedService() -> CBMutableService {
        
        let newService = CBMutableService(type: CBUUID(string: serviceUUID), primary: primary)
        
        for characteristic in characteristics {
            
            let newCharacteristic = characteristic.constructedCharacteristic()
            characteristicUpdateCallbacks[newCharacteristic.uuid] = characteristic.updateCallback
           
            if newService.characteristics != nil {
               newService.characteristics!.append(newCharacteristic)
            } else {
               newService.characteristics = [newCharacteristic]
            }
        }
        
        return newService
    }
}
