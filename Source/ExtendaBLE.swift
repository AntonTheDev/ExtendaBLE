//
//  ExtendaBLE.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/29/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

class ExtendaBLE {
    
    public class func newCentralManager(queue: DispatchQueue? = nil, central : (_ central : EBCentralManagerMaker) -> Void) -> EBCentralManager {
        let newManager = EBCentralManagerMaker(queue: queue)
        central(newManager)
        return newManager.constructedCentralManager()
    }
   
    
    #if !os(tvOS)
    public class func newPeripheralManager(queue: DispatchQueue? = nil, peripheral : (_ peripheral : EBPeripheralManagerMaker) -> Void) -> EBPeripheralManager {
        let newManager = EBPeripheralManagerMaker(queue: queue)
        peripheral(newManager)
        return newManager.constructedPeripheralManager()
    }
    #endif
}

extension EBCentralManagerMaker {
    
    @discardableResult public func peripheralName(_ peripheralName : String) -> EBCentralManagerMaker {
        self.peripheralName = peripheralName
        return self
    }
    
    @discardableResult public func addService(_ uuid: String,
                                              primary isPrimary: Bool = true,
                                              service : (_ service : EBServiceMaker) -> Void) -> EBCentralManagerMaker {
        let newService = EBServiceMaker(uuid, primary: isPrimary)
        services.append(newService)
        service(newService)
        return self
    }
}

#if !os(tvOS)
extension EBPeripheralManagerMaker {
    
    @discardableResult public func localName(_ localname : String) -> EBPeripheralManagerMaker {
        self.localName = localname
        return self
    }
    
    @discardableResult public func addService(_ uuid: String,
                                              primary isPrimary: Bool = true,
                                              service : (_ service : EBServiceMaker) -> Void) -> EBPeripheralManagerMaker {
        let newService = EBServiceMaker(uuid, primary: isPrimary)
        services.append(newService)
        service(newService)
        return self
    }
}
#endif

extension EBServiceMaker {
    
    @discardableResult public func addProperty(_ UUID: String) -> EBCharacteristicMaker {
        let characteristic = EBCharacteristicMaker(uuid : UUID)
        characteristics.append(characteristic)
        return characteristic
    }
}


extension EBCharacteristicMaker {
    
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
