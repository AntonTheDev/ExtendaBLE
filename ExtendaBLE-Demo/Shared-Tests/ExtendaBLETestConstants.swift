//
//  ExtendaBLETestConstants.swift
//  ExtendaBLE
//
//  Created by Anton on 4/14/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

/**
 *  Service / Characteristic String Representation
 */
let Service1UUIDKey          = "a495ff20-c5b1-4b44-b512-1370f02d74de"
let Characteristic1UUIDKey   = "a495ff21-c5b1-4b44-b512-1370f02d74de"
let Characteristic2UUIDKey   = "a495ff22-c5b1-4b44-b512-1370f02d74de"
let Characteristic3UUIDKey   = "a495ff23-c5b1-4b44-b512-1370f02d74de"

let Service2UUIDKey          = "a495ff28-c5b1-4b44-b512-1370f02d74de"
let Characteristic4UUIDKey   = "a495ff24-c5b1-4b44-b512-1370f02d74de"
let Characteristic5UUIDKey   = "a495ff25-c5b1-4b44-b512-1370f02d74de"
let Characteristic6UUIDKey   = "a495ff26-c5b1-4b44-b512-1370f02d74de"

/**
 *  CBUUID Representation of the string above
 */
let Service1UUID          = CBUUID(string : Service1UUIDKey)
let Characteristic1UUID   = CBUUID(string : Characteristic1UUIDKey)
let Characteristic2UUID   = CBUUID(string : Characteristic2UUIDKey)
let Characteristic3UUID   = CBUUID(string : Characteristic3UUIDKey)

let Service2UUID          = CBUUID(string : Service2UUIDKey)
let Characteristic4UUID   = CBUUID(string : Characteristic4UUIDKey)
let Characteristic5UUID   = CBUUID(string : Characteristic5UUIDKey)
let Characteristic6UUID   = CBUUID(string : Characteristic6UUIDKey)

/**
 *  Mock Central UUIDs
 */
let Central1              = UUID(uuidString : "972DCEEA-22EC-4C2B-B904-8A7C0DB5F972")
let Central2              = UUID(uuidString : "48E8D879-0D2D-4298-9CE8-FFC94E743A02")

/**
 *  Mock Peripheral UUIDs
 */
let Peripheral1           = UUID(uuidString : "37719C7F-1D89-45C5-8AE1-452F458EB0BB")
let Peripheral2           = UUID(uuidString : "48E8D879-0D2D-4298-9CE8-FFC94E743A02")


var testValueString : String {
    get {
        return "Hello this is a faily long string to check how many bytes lets make this a lot longer even longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer an longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer XXXXXXXXXXXXXXXX"
    }
}
