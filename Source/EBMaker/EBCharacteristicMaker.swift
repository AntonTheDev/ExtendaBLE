//
//  EBCharacteristicMaker.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public class EBCharacteristicMaker {
    
    internal var uuid : String
    internal var value : Data?
    internal var updateCallback : EBTransactionCallback?
    internal var packetsEnabled : Bool = false
    
    internal var permissions : CBAttributePermissions = [.readable, .writeable]
    internal var properties : CBCharacteristicProperties =  [.read, .write, .notify]
    
    required public init(uuid UUID: String, primary isPrimary: Bool = true) {
        uuid = UUID
    }
    
    func constructedCharacteristic() -> CBMutableCharacteristic? {
        
        #if os(tvOS) || os(watchOS)
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
    
    @discardableResult public func packetsEnabled(_ packetsEnabled : Bool) -> EBCharacteristicMaker {
        self.packetsEnabled = packetsEnabled
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

