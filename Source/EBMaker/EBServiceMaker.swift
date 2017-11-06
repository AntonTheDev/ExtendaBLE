//
//  EBServiceMaker.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public class EBServiceMaker {
    
    internal var serviceUUID        : String
    internal var primary            : Bool = true
    internal var characteristics    = [EBCharacteristicMaker]()
    
    internal var packetBasedCharacteristicUUIDS  : [CBUUID] {
        get {
            return characteristics.filter { $0.packetsEnabled == true }.map {CBUUID(string: $0.uuid) }
        }
    }
    
    internal var characteristicUpdateCallbacks = [CBUUID : EBTransactionCallback]()
    
    required public init(_ uuid: String) {
        serviceUUID = uuid
    }
    
    internal func constructedService() -> CBMutableService? {
        
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
            }
            
            return newService
        #endif
    }

    @discardableResult public func addCharacteristic(_ UUID: String, maker : (_ characteristic : EBCharacteristicMaker) -> Void) -> EBServiceMaker {
        let characteristic = EBCharacteristicMaker(uuid : UUID)
        maker(characteristic)
        characteristics.append(characteristic)
        return self
    }
    
    @discardableResult public func primary(_ primary : Bool) -> EBServiceMaker {
        self.primary = primary
        return self
    }
}

