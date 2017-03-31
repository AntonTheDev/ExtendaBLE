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
    
    public class func newCentralManager(queue: DispatchQueue? = nil, central : (_ central : EBCentralMaker) -> Void) -> EBCentralManager {
        let newManager = EBCentralMaker(queue: queue)
        central(newManager)
        return newManager.constructedCentralManager()
    }
    
    public class func newPeripheralManager(queue: DispatchQueue? = nil, peripheral : (_ peripheral : EBPeripheralMaker) -> Void) -> EBPeripheralManager {
        let newManager = EBPeripheralMaker(queue: queue)
        peripheral(newManager)
        return newManager.constructedPeripheralManager()
    }
}

