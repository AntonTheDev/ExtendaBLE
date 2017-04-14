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
    public class func setLogLevel(_ logLevel : LogLevel) {
        ExtendableLoggingConfig.logLevel = logLevel
    }
}
