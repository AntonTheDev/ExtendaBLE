//
//  EBCDefinitions.swift
//  ExtendaBLE
//
//  Created by Anton on 4/3/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

/* Shared Enum for Manager State for OSX and backwards compatibility for iOS/tvOS */

public enum EBManagerState : Int {
    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn
}

/* Central Manager Delegate Callbacks */

public typealias CentralManagerStateChangeCallback = ((_ state: EBManagerState) -> Void)
public typealias CentralManagerDidDiscoverCallback = ((_ peripheral: CBPeripheral, _ advertisementData: [String : Any], _ rssi: NSNumber) -> Void)
public typealias CentralManagerPeripheralConnectionCallback = ((_ connected : Bool, _ peripheral: CBPeripheral, _ error: Error?) -> Void)

/* Peripheral Manager Delegate Callbacks */

public typealias PeripheralManagerStateChangeCallBack = ((_ state: EBManagerState) -> Void)
public typealias PeripheralManagerDidStartAdvertisingCallBack = ((_ started : Bool, _ error: Error?) -> Void)
public typealias PeripheralManagerDidAddServiceCallBack = ((_ service: CBService, _ error: Error?) -> Void)
public typealias PeripheralManagerSubscriopnChangeToCallBack = ((_ subscribed : Bool, _ central: CBCentral, _ characteristic: CBCharacteristic) -> Void)
public typealias PeripheralManagerIsReadyToUpdateCallBack = (() -> Void)

/* Callback definitions for characteristic value changes */

public typealias CharacteristicWriteCallback = ((_ data: Data) -> Void)
public typealias CharacteristicUpdateCallback = ((_ data: Data) -> Void)

/***
 *  Service added to the central and peripheral if one of the
 *  chracteristics in the definition is packet based. This will
 *  communicate the preferred mtu (packet size) to split the 
 *  data into packets when communicating large data
 ***/

public let mtuServiceUUIDKey = "F80A41CA-8B71-47BE-8A92-E05BB5F1F862"
public let mtuCharacteristicUUIDKey = "37CD1740-6822-4D85-9AAF-C2378FDC4329"

func newMTUService() -> CBMutableService? {
    
    #if os(tvOS) || os(watchOS)
        return nil
    #else
        let mtuService = CBMutableService(type: CBUUID(string: mtuServiceUUIDKey), primary: true)
        let mtuCharacteristic =  CBMutableCharacteristic(type: CBUUID(string: mtuCharacteristicUUIDKey),
                                                         properties: [.notify, .read], value: nil,
                                                         permissions: [.readable])
        
        mtuService.characteristics = [mtuCharacteristic]
        return mtuService
    #endif
}
