//
//  EBCDefinitions.swift
//  ExtendaBLE
//
//  Created by Anton on 4/3/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public enum EBManagerState : Int {
    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn
}

public typealias CentralManagerStateChangeCallback = ((_ state: EBManagerState) -> Void)
public typealias CentralManagerDidDiscoverCallback = ((_ peripheral: CBPeripheral, _ advertisementData: [String : Any], _ rssi: NSNumber) -> Void)
public typealias CentralManagerPeripheralConnectionCallback = ((_ connected : Bool, _ peripheral: CBPeripheral, _ error: Error?) -> Void)


public typealias PeripheralManagerStateChangeCallBack = ((_ state: EBManagerState) -> Void)
public typealias PeripheralManagerDidStartAdvertisingCallBack = ((_ started : Bool, _ error: Error?) -> Void)
public typealias PeripheralManagerDidAddServiceCallBack = ((_ service: CBService, _ error: Error?) -> Void)
public typealias PeripheralManagerSubscriopnChangeToCallBack = ((_ subscribed : Bool, _ central: CBCentral, _ characteristic: CBCharacteristic) -> Void)
public typealias PeripheralManagerIsReadyToUpdateCallBack = (() -> Void)
