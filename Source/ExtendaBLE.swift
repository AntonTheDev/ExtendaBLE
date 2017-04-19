//
//  ExtendaBLE.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/29/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public class ExtendaBLE {
    
    /// Enable logging for debugging
    ///
    /// - Parameter logLevel: log level
    public class func setLogLevel(_ logLevel : LogLevel) {
        ExtendableLoggingConfig.logLevel = logLevel
    }
    

    /// Create a new central using the recursive makers
    ///
    /// - Parameters:
    ///   - queue: user degine queue for the central
    ///   - central: recursive callback to configure the central manager
    /// - Returns: new configured instance of the central manager
    public class func newCentralManager(queue: DispatchQueue? = nil, _ central : (_ central : EBCentralManagerMaker) -> Void) -> EBCentralManager {
        let newManager = EBCentralManagerMaker(queue: queue)
        central(newManager)
        return newManager.constructedCentralManager()
    }

    
    /// Create a new peripheral using the recursive makers.
    ///
    /// NoteL This method is not available on tvDS, since the AppleTV cannot act as a periphral
    ///
    /// - Parameters:
    ///   - queue: user degine queue for the peripheral
    ///   - central: recursive callback to configure the peripheral manager
    /// - Returns: new configured instance of the peripheral manager
    #if !os(tvOS)
    public class func newPeripheralManager(queue: DispatchQueue? = nil, peripheral : (_ peripheral : EBPeripheralManagerMaker) -> Void) -> EBPeripheralManager {
        let newManager = EBPeripheralManagerMaker(queue: queue)
        peripheral(newManager)
        return newManager.constructedPeripheralManager()
    }
    #endif
}
