//
//  EBCharacteristicMaker.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth
/*
public class EBCharacteristicMaker {
    
    private var uuid : String
    private var value : Data?
    private var updateCallback : EBTransactionCallback?
    private var chunkingEnabled : Bool = false
    
    private var permissions : CBAttributePermissions = [.readable, .writeable]
    private var properties : CBCharacteristicProperties =  [.read, .write, .notify]
    
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

    @discardableResult public func properties(_ properties : CBCharacteristicProperties) -> EBCharacteristicMaker {
        self.properties = properties
        return self
    }
    
    @discardableResult public func permissions(_ permissions : CBAttributePermissions) -> EBCharacteristicMaker {
        self.permissions = permissions
        return self
    }
    
    @discardableResult public func chunkingEnabled(_ chunkingEnabled : Bool) -> EBCharacteristicMaker {
        self.chunkingEnabled = chunkingEnabled
        return self
    }
    
    @discardableResult public func value(_ value : Data) -> EBCharacteristicMaker {
        self.value = value
        return self
    }
    
    @discardableResult public func onUpdate(_ updateCallback : @escaping EBTransactionCallback) -> EBCharacteristicMaker {
        self.updateCallback = updateCallback
        return self
    }
}
*/
