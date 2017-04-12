//
//  ExtendaBLE.swift
//  ExtendaBLE
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
