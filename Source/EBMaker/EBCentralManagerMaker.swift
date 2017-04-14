//
//  EBCentralManagerMaker.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/23/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

extension ExtendaBLE {
    
    public class func newCentralManager(queue: DispatchQueue? = nil, _ central : (_ central : EBCentralManagerMaker) -> Void) -> EBCentralManager {
        let newManager = EBCentralManagerMaker(queue: queue)
        central(newManager)
        return newManager.constructedCentralManager()
    }
}

public class EBCentralManagerMaker  {
    
    private var queue              : DispatchQueue?

    // The peripheral name to search for, the central will attempt to connect if defined
    // otherwise it will scan for registered services defined during constructions only
    private var peripheralName             : String?

    // Reconnect on start stores devices we haev connected to prior
    private var reconnectOnStart           = true
    private var reconnectTimeout           = 2.0
    private var reconnectCacheKey          = "EBCentralManagerDefaultPeripheralCacheKey"

    // If no devices are found it will rescan after the internal specified if 
    // supportMutiplePeripherals property is set to false, and the interval is greater than 0.
    // The scanTimeout will stop scanning after the default 10 seconds, and restart if 
    // the configuration meets the criteria in the prior statement.
    private var rescanInterval             = 0.0
    private var scanTimeout                = 10.0

    // Manager, Scan, Connection Options
    private var supportMutiplePeripherals  = false
    private var enablePowerAlert           = true
    private var notifyOnConnection         = false
    private var notifyOnDisconnect         = false
    private var notifyOnNotification       = false

    // Delegate Callbacks
    private var stateChangeCallBack                : CentralManagerStateChangeCallback?
    private var didDiscoverCallBack                : CentralManagerDidDiscoverCallback?
    private var peripheralConnectionCallback       : CentralManagerPeripheralConnectionCallback?
    
    private var services = [EBServiceMaker]()
    
    required public init(queue: DispatchQueue?) {
        self.queue = queue
    }
    
    fileprivate func constructedCentralManager() -> EBCentralManager {
        
        let options = configurationOptions()
        
        let newCentralManager = EBCentralManager(queue: queue, options : options.managerOptions)
        
        for service in services {
            
            for (uuid, updateCallback) in service.characteristicUpdateCallbacks {
                newCentralManager.registeredCharacteristicCallbacks[uuid] = updateCallback
            }
            
            newCentralManager.registeredServiceUUIDs.append(CBUUID(string: service.serviceUUID))
            newCentralManager.chunkedCharacteristicUUIDS += service.chunkedCharacteristicUUIDS
        }
        
        if  newCentralManager.chunkedCharacteristicUUIDS.count > 0 {
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
    
    private func configurationOptions() -> (managerOptions : [String : Any], scanOptions : [String : Any], connectionOptions: [String : Any]) {
       
        var managerOptions      = [String : Any]()
        var scanOptions         = [String : Any]()
        var connectionOptions   = [String : Any]()
        
        if enablePowerAlert {
            managerOptions[CBCentralManagerOptionShowPowerAlertKey] = NSNumber(booleanLiteral: true)
        }

        if supportMutiplePeripherals {
            scanOptions[CBCentralManagerScanOptionAllowDuplicatesKey] = NSNumber(booleanLiteral: true)
        }
        
        #if !os(OSX)
            if notifyOnConnection {
                connectionOptions[CBConnectPeripheralOptionNotifyOnConnectionKey] = NSNumber(booleanLiteral: true)
            }
            
            if notifyOnNotification {
                connectionOptions[CBConnectPeripheralOptionNotifyOnNotificationKey] = NSNumber(booleanLiteral: true)
            }
        #endif
        
       
        
        if notifyOnDisconnect {
            connectionOptions[CBConnectPeripheralOptionNotifyOnDisconnectionKey] = NSNumber(booleanLiteral: true)
        }
        
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
