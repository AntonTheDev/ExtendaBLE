//
//  EBCentralManagerMaker.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth


public class EBCentralManagerMaker  {
    
    internal var queue              : DispatchQueue?

    // The peripheral name to search for, the central will attempt to connect if defined
    // otherwise it will scan for registered services defined during constructions only
    internal var peripheralName             : String?

    // Reconnect on start stores devices we haev connected to prior
    internal var reconnectOnStart           = true
    internal var reconnectTimeout           = 2.0
    internal var reconnectCacheKey          = "EBCentralManagerDefaultPeripheralCacheKey"

    // If no devices are found it will rescan after the internal specified if 
    // supportMutiplePeripherals property is set to false, and the interval is greater than 0.
    // The scanTimeout will stop scanning after the default 10 seconds, and restart if 
    // the configuration meets the criteria in the prior statement.
    internal var rescanInterval             = 0.0
    internal var scanTimeout                = 10.0

    // Manager, Scan, Connection Options
    internal var supportMutiplePeripherals  = false
    internal var enablePowerAlert           = true
    internal var notifyOnConnection         = false
    internal var notifyOnDisconnect         = false
    internal var notifyOnNotification       = false

    // Delegate Callbacks
    internal var stateChangeCallBack                : CentralManagerStateChangeCallback?
    internal var didDiscoverCallBack                : CentralManagerDidDiscoverCallback?
    internal var peripheralConnectionCallback       : CentralManagerPeripheralConnectionCallback?
    
    internal var services = [EBServiceMaker]()
    
    required public init(queue: DispatchQueue?) {
        self.queue = queue
    }
    
    internal func constructedCentralManager() -> EBCentralManager {
        
        let options = configurationOptions()
        
        let newCentralManager = EBCentralManager(queue: queue, options : options.managerOptions)
        
        for service in services {
            
            for (uuid, updateCallback) in service.characteristicUpdateCallbacks {
                newCentralManager.registeredCharacteristicCallbacks[uuid] = updateCallback
            }
            
            for (uuid, updateCallback) in service.characteristicUpdateCallbacks {
                newCentralManager.registeredCharacteristicCallbacks[uuid] = updateCallback
            }
            
            
            newCentralManager.registeredServiceUUIDs.append(CBUUID(string: service.serviceUUID))
            newCentralManager.packetBasedCharacteristicUUIDS += service.packetBasedCharacteristicUUIDS
        }
        
        if newCentralManager.packetBasedCharacteristicUUIDS.count > 0 {
            newCentralManager.registeredServiceUUIDs.append(CBUUID(string: mtuServiceUUIDKey))
        }
        
        newCentralManager.peripheralName                = peripheralName
        newCentralManager.reconnectOnStart              = reconnectOnStart
        newCentralManager.supportMutiplePeripherals     = supportMutiplePeripherals
        newCentralManager.reconnectTimeout              = reconnectTimeout
        newCentralManager.rescanInterval                = rescanInterval
        newCentralManager.scanTimeout                   = scanTimeout
        newCentralManager.reconnectCacheKey             = reconnectCacheKey
        newCentralManager.scanOptions                   = options.scanOptions
        newCentralManager.connectionOptions             = options.connectionOptions
        newCentralManager.peripheralConnectionCallback  = peripheralConnectionCallback
        newCentralManager.didDiscoverCallBack           = didDiscoverCallBack
        newCentralManager.stateChangeCallBack           = stateChangeCallBack
        
        return newCentralManager
    }
    
    @discardableResult public func addService(_ uuid: String,
                                              service : (_ service : EBServiceMaker) -> Void) -> EBCentralManagerMaker {
        let newService = EBServiceMaker(uuid)
        services.append(newService)
        service(newService)
        return self
    }
    
    internal func configurationOptions() -> (managerOptions : [String : Any], scanOptions : [String : Any], connectionOptions: [String : Any]) {
       
        var managerOptions      = [String : Any]()
        var scanOptions         = [String : Any]()
        var connectionOptions   = [String : Any]()
        
        managerOptions[CBCentralManagerOptionShowPowerAlertKey] = NSNumber(booleanLiteral: enablePowerAlert)
 
        scanOptions[CBCentralManagerScanOptionAllowDuplicatesKey] = NSNumber(booleanLiteral: supportMutiplePeripherals)
        
        connectionOptions[CBConnectPeripheralOptionNotifyOnDisconnectionKey] = NSNumber(booleanLiteral: notifyOnDisconnect)

    #if !os(OSX)
        connectionOptions[CBConnectPeripheralOptionNotifyOnConnectionKey] = NSNumber(booleanLiteral: notifyOnConnection)
        connectionOptions[CBConnectPeripheralOptionNotifyOnNotificationKey] = NSNumber(booleanLiteral: notifyOnNotification)
    #endif
    
        return (managerOptions, scanOptions, connectionOptions)
    }
    
    @discardableResult public func peripheralName(_ peripheralName : String) -> EBCentralManagerMaker {
        self.peripheralName = peripheralName
        return self
    }
    
    @discardableResult public func reconnectOnStart(_ reconnectOnStart : Bool) -> EBCentralManagerMaker {
        self.reconnectOnStart = reconnectOnStart
        return self
    }
    
    @discardableResult public func reconnectTimeout(_ reconnectTimeout : Double) -> EBCentralManagerMaker {
        self.reconnectTimeout = reconnectTimeout
        return self
    }
    
    @discardableResult public func reconnectCacheKey(_ reconnectCacheKey : String) -> EBCentralManagerMaker {
        self.reconnectCacheKey = reconnectCacheKey
        return self
    }
    
    @discardableResult public func rescanInterval(_ rescanInterval : Double) -> EBCentralManagerMaker {
        self.rescanInterval = rescanInterval
        return self
    }
    
    @discardableResult public func scanTimeout(_ scanTimeout : Double) -> EBCentralManagerMaker {
        self.scanTimeout = scanTimeout
        return self
    }
    
    @discardableResult public func supportMutiplePeripherals(_ supportMutiplePeripherals : Bool) -> EBCentralManagerMaker {
        self.supportMutiplePeripherals = supportMutiplePeripherals
        return self
    }
    
    @discardableResult public func enablePowerAlert(_ enablePowerAlert : Bool) -> EBCentralManagerMaker {
        self.enablePowerAlert = enablePowerAlert
        return self
    }
    
    #if !os(OSX)
    @discardableResult public func notifyOnConnection(_ notifyOnConnection : Bool) -> EBCentralManagerMaker {
        self.notifyOnConnection = notifyOnConnection
        return self
    }
    
    @discardableResult public func notifyOnNotification(_ notifyOnNotification : Bool) -> EBCentralManagerMaker {
        self.notifyOnNotification = notifyOnNotification
        return self
    }
    #endif
    
    @discardableResult public func notifyOnDisconnect(_ notifyOnDisconnect : Bool) -> EBCentralManagerMaker {
        self.notifyOnDisconnect = notifyOnDisconnect
        return self
    }
    
    @discardableResult public func onStateChange(_ callback : @escaping CentralManagerStateChangeCallback) -> EBCentralManagerMaker {
        stateChangeCallBack = callback
        return self
    }
    
    @discardableResult public func onDidDiscover(_ callback : @escaping CentralManagerDidDiscoverCallback) -> EBCentralManagerMaker {
        didDiscoverCallBack = callback
        return self
    }
    
    @discardableResult public func onPeripheralConnectionChange(_ callback : @escaping CentralManagerPeripheralConnectionCallback) -> EBCentralManagerMaker {
        peripheralConnectionCallback = callback
        return self
    }
}
