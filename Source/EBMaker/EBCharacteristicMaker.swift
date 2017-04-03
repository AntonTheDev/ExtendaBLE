//
//  EBCharacteristicMaker.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public class EBCharacteristicMaker {
    
    var uuid : String
    var value : Data?
    var updateCallback : EBTransactionCallback?
    var chunkingEnabled : Bool = false
    
    var permissions : CBAttributePermissions = [.readable, .writeable]
    var properties : CBCharacteristicProperties =  [.read, .write, .notify]
    
    required public init(uuid UUID: String, primary isPrimary: Bool = true) {
        uuid = UUID
    }
    
    func constructedCharacteristic() -> CBMutableCharacteristic? {
        
        #if os(tvOS)
            return nil
        #else
            return CBMutableCharacteristic(type: CBUUID(string: uuid), properties: properties, value: value, permissions: permissions)
        #endif
    }
}
