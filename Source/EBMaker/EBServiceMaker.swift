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
    
    internal var serviceUUID  : String
    private var primary      : Bool = true
    private var characteristics             = [EBCharacteristicMaker]()
    
    var chunkedCharacteristicUUIDS  : [CBUUID] {
        get {
            return characteristics.filter { $0.chunkingEnabled == true }.map {CBUUID(string: $0.uuid) }
        }
    }
    
    internal var characteristicUpdateCallbacks = [CBUUID : EBTransactionCallback]()
    
    required public init(_ uuid: String) {
        serviceUUID = uuid
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

public class EBCharacteristicMaker {
    
    fileprivate var uuid : String
    fileprivate var value : Data?
    fileprivate var updateCallback : EBTransactionCallback?
    fileprivate var chunkingEnabled : Bool = false
    
    fileprivate var permissions : CBAttributePermissions = [.readable, .writeable]
    fileprivate var properties : CBCharacteristicProperties =  [.read, .write, .notify]
    
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

