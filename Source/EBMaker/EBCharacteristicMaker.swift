//
//  EBCharacteristicMaker.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public typealias CharacteristicWriteCallback = ((_ data: Data) -> Void)
public typealias CharacteristicUpdateCallback = ((_ data: Data) -> Void)

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
    
    func constructedCharacteristic() -> CBMutableCharacteristic? {
        
        #if os(tvOS)
            return nil
        #else
            return CBMutableCharacteristic(type: CBUUID(string: uuid), properties: properties, value: value, permissions: permissions)
        #endif
    }
}
