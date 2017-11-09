//
//  ExtendableCMMakerTests.swift
//  ExtendaBLE-iOS-DemoTests
//
//  Created by Anton Doudarev on 11/9/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import XCTest
import CoreBluetooth

@testable import ExtendaBLE

class ExtendableCMMakerTests: XCTestCase {
    
    override func setUp() { super.setUp() }
    override func tearDown() { super.tearDown() }
    
    /// Test CentralManager Configuration
    func testCMConfig() {
        
        let cm = ExtendaBLE.newCentralManager { (manager) in
            manager.peripheralName("Test Name")
            manager.supportMutiplePeripherals(true)
            manager.reconnectOnStart(false)
            manager.reconnectCacheKey("TestCacheKey")
            manager.reconnectTimeout(30)
            manager.rescanInterval(400)
            manager.scanTimeout(5)
            
            manager.onPeripheralConnectionChange{ (connected, peripheral, error) in }
                .onDidDiscover { (peripheral, advData, RSSI) in }
                .onStateChange{ (state) in }
        }
        
        XCTAssertEqual(cm.peripheralName, "Test Name", "CM - supportMutiplePeripherals misconfigured")
        
        XCTAssertTrue(cm.supportMutiplePeripherals, "CM - supportMutiplePeripherals misconfigured")
        XCTAssertFalse(cm.reconnectOnStart, "CM - reconnectOnStart misconfigured")
        XCTAssertEqual(cm.reconnectCacheKey,"TestCacheKey", "CM - reconnectCacheKey misconfigured")
        XCTAssertEqual(cm.reconnectTimeout, 30, "CM - reconnectTimeout misconfigured")
        XCTAssertEqual(cm.rescanInterval, 400, "CM - rescanInterval misconfigured")
        XCTAssertEqual(cm.scanTimeout, 5, "CM - scanTimeout misconfigured")
        
        XCTAssertNotNil(cm.stateChangeCallBack, "CM - stateChangeCallBack callback missing")
        XCTAssertNotNil(cm.didDiscoverCallBack, "CM - didDiscoverCallBack callback missing")
        XCTAssertNotNil(cm.peripheralConnectionCallback, "CM - peripheralConnectionCallback callback missing")
        XCTAssertEqual(cm.packetBasedCharacteristicUUIDS.count, 0, "CM - Incorrect number of packet based characteristics")
    }
    
    /// Test CentralManager Configuration
    func testCMOptions() {
        
        let defaultCentral = ExtendaBLE.newCentralManager { (manager) in }
        
        XCTAssertEqual(defaultCentral.managerOptions.keys.count, 1, "CM - managerOptions defaults misconfigured")
        XCTAssertEqual(defaultCentral.scanOptions.keys.count, 1, "CM - scanOptions defaults misconfigured")
        XCTAssertEqual(defaultCentral.connectionOptions.keys.count, 3, "CM - connectionOptions defaults misconfigured")
        
        XCTAssertTrue(defaultCentral.managerOptions[CBCentralManagerOptionShowPowerAlertKey] as! Bool,
                      "CM - default managerOptions misconfigured")
        
        XCTAssertFalse(defaultCentral.scanOptions[CBCentralManagerScanOptionAllowDuplicatesKey] as! Bool,
                       "CM - default scanOptions misconfigured")
        
        XCTAssertFalse(defaultCentral.connectionOptions[CBConnectPeripheralOptionNotifyOnConnectionKey] as! Bool,
                       "CM - default connectionOptions misconfigured")
        
        XCTAssertFalse(defaultCentral.connectionOptions[CBConnectPeripheralOptionNotifyOnDisconnectionKey] as! Bool,
                       "CM - default connectionOptions misconfigured")
        
        XCTAssertFalse(defaultCentral.connectionOptions[CBConnectPeripheralOptionNotifyOnNotificationKey] as! Bool,
                       "CM - default connectionOptions misconfigured")
        
        let configuredCentral = ExtendaBLE.newCentralManager { (manager) in
            manager.supportMutiplePeripherals(false)
            manager.enablePowerAlert(false)
            manager.notifyOnConnection(true)
            manager.notifyOnDisconnect(true)
            manager.notifyOnNotification(true)
            
            XCTAssertFalse(manager.enablePowerAlert,             "CMM - enablePowerAlert misconfigured")
            XCTAssertFalse(manager.supportMutiplePeripherals,    "CMM - supportMutiplePeripherals misconfigured")
            
            XCTAssertTrue(manager.notifyOnConnection,   "CMM - notifyOnConnection misconfigured")
            XCTAssertTrue(manager.notifyOnDisconnect,   "CMM - notifyOnDisconnect misconfigured")
            XCTAssertTrue(manager.notifyOnNotification, "CMM - notifyOnNotification misconfigured")
        }
        
        XCTAssertEqual(configuredCentral.managerOptions.keys.count, 1, "CM - managerOptions defaults misconfigured")
        XCTAssertEqual(configuredCentral.scanOptions.keys.count, 1, "CM - scanOptions defaults misconfigured")
        XCTAssertEqual(configuredCentral.connectionOptions.keys.count, 3, "CM - connectionOptions defaults misconfigured")
        
        XCTAssertFalse(configuredCentral.managerOptions[CBCentralManagerOptionShowPowerAlertKey] as! Bool,
                       "CM - non-default managerOptions misconfigured")
        
        XCTAssertFalse(configuredCentral.scanOptions[CBCentralManagerScanOptionAllowDuplicatesKey] as! Bool,
                       "CM - non-default scanOptions misconfigured")
        
        XCTAssertTrue(configuredCentral.connectionOptions[CBConnectPeripheralOptionNotifyOnConnectionKey] as! Bool,
                      "CM - non-default connectionOptions misconfigured")
        
        XCTAssertTrue(configuredCentral.connectionOptions[CBConnectPeripheralOptionNotifyOnDisconnectionKey] as! Bool,
                      "CM - non-default connectionOptions misconfigured")
        
        XCTAssertTrue(configuredCentral.connectionOptions[CBConnectPeripheralOptionNotifyOnNotificationKey] as! Bool,
                      "CM - non-default connectionOptions misconfigured")
    }
    
    /// Test Service Configuration on the Central Manager
    func testCentralServiceConfig() {
        
        let cm = ExtendaBLE.newCentralManager { (manager) in
            
            manager.addService(Service1UUIDKey) {(service) in
                
                service.addCharacteristic(Characteristic1UUIDKey) { (characteristic) in }
                    .addCharacteristic(Characteristic2UUIDKey) { (characteristic) in }
                    .addCharacteristic(Characteristic3UUIDKey) { (characteristic) in }
                
                XCTAssertTrue(service.primary,"CSM - Service did not default to primary" )
                XCTAssertEqual(service.characteristics.count, 3, "CSM - Service Did Not Register Correct Number of Characteristics")
                XCTAssertEqual(service.packetBasedCharacteristicUUIDS.count, 0, "CSM - Incorrect Number of Packet Based Characteristics")
                
                }.addService(Service2UUIDKey) { (service) in
                    service.primary(false)
                    
                    service.addCharacteristic(Characteristic4UUIDKey) { (characteristic) in }
                        .addCharacteristic(Characteristic6UUIDKey) { (characteristic) in
                    }
                    
                    XCTAssertEqual(service.characteristics.count, 2, "CSM - Service Did Not Register Correct Number of Characteristics")
                    XCTAssertTrue(service.primary == false ,"CSM - Service Should Not Be Primary" )
                    XCTAssertEqual(service.packetBasedCharacteristicUUIDS.count, 0, "CSM - Incorrect Number of Packet Based Characteristics")
            }
        }
        
        XCTAssertEqual(cm.registeredServiceUUIDs.count, 2, "CM - Invalid Number of Services (Missing MTU Service?)")
        XCTAssertEqual(cm.packetBasedCharacteristicUUIDS.count, 0, "CM - Incorrect number of packet based characteristics")
    }
    
    /// Characteristic Configuration on the Services Registered for the Central Manager
    func testCentralCharacteristicConfig() {
        
        let cm = ExtendaBLE.newCentralManager { (manager) in
            
            manager.addService(Service1UUIDKey) {(service) in
                service.addCharacteristic(Characteristic1UUIDKey) { (characteristic) in
                    
                    characteristic.properties([.read])
                    characteristic.permissions([.readable])
                    characteristic.packetsEnabled(true)
                    
                    }.addCharacteristic(Characteristic2UUIDKey) { (characteristic) in
                        characteristic.properties([.write])
                        characteristic.permissions([.writeable])
                    }.addCharacteristic(Characteristic3UUIDKey) { (characteristic) in
                        characteristic.properties([.read, .write, .notify])
                        characteristic.permissions([.readable, .writeable])
                        
                        characteristic.onUpdate({ (data, error) in })
                }
                
                if let char1 = service.characteristics.filter({ $0.uuid == Characteristic1UUIDKey }).first {
                    XCTAssertTrue(char1.properties.contains(.read), "CCRM - Characteristic Registered Incorrect properties")
                    XCTAssertTrue(!char1.properties.contains(.write), "CCRM - Characteristic Registered Incorrect properties")
                    XCTAssertTrue(!char1.properties.contains(.notify), "CCRM - Characteristic Registered Incorrect properties")
                }
                
                if let char2 = service.characteristics.filter({ $0.uuid == Characteristic2UUIDKey }).first {
                    XCTAssertTrue(char2.properties.contains(.write), "CCRM - Characteristic Registered Incorrect properties")
                    XCTAssertTrue(!char2.properties.contains(.read), "CCRM - Characteristic Registered Incorrect properties")
                    XCTAssertTrue(!char2.properties.contains(.notify), "CCRM - Characteristic Registered Incorrect properties")
                }
                
                if let char3 = service.characteristics.filter({ $0.uuid == Characteristic3UUIDKey }).first {
                    XCTAssertTrue(char3.properties.contains(.read), "CCRM - Characteristic Registered Incorrect properties")
                    XCTAssertTrue(char3.properties.contains(.write), "CCRM - Characteristic Registered Incorrect properties")
                    XCTAssertTrue(char3.properties.contains(.notify), "CCRM - Characteristic Registered Incorrect properties")
                    XCTAssertTrue(!char3.properties.contains(.writeWithoutResponse), "SM - Service Registered Incorrect properties")
                    XCTAssertTrue(!char3.properties.contains(.indicate), "CCRM - Characteristic Registered Incorrect properties")
                    XCTAssertNotNil(char3.updateCallback, "CCRM - Characteristic updateCallback callback missing")
                }
                
                XCTAssertEqual(service.characteristics.count, 3, "CSM - Service Did Not Register Correct Number of Characteristics")
                XCTAssertEqual(service.packetBasedCharacteristicUUIDS.count, 1, "CSM - Service conrainsIncorrect Number of Packet Based Characteristics")
                XCTAssertTrue(service.packetBasedCharacteristicUUIDS.contains(Characteristic1UUID), "CSM - Characteristic2UUIDKey should be packet based")
                
                }.addService(Service2UUIDKey) { (service) in
                    
                    service.addCharacteristic(Characteristic4UUIDKey) { (characteristic) in
                        characteristic.packetsEnabled(true)
                        }.addCharacteristic(Characteristic5UUIDKey) { (characteristic) in
                        }.addCharacteristic(Characteristic6UUIDKey) { (characteristic) in
                            characteristic.packetsEnabled(true)
                    }
                    
                    XCTAssertEqual(service.characteristics.count, 3, "SM - Did Not Register Correct Number of Characteristics")
                    XCTAssertEqual(service.packetBasedCharacteristicUUIDS.count, 2, "SM - Incorrect Number of Packet Based Characteristics")
                    XCTAssertTrue(service.packetBasedCharacteristicUUIDS.contains(Characteristic4UUID), "SM - Characteristic6UUIDKey should be packet based")
                    XCTAssertTrue(service.packetBasedCharacteristicUUIDS.contains(Characteristic6UUID), "SM - Characteristic6UUIDKey no packet based")
            }
        }
        
        XCTAssertEqual(cm.registeredServiceUUIDs.count, 3, "CM - Invalid Number of Services (Missing MTU Service?)")
        XCTAssertTrue(cm.packetBasedCharacteristicUUIDS.contains(Characteristic1UUID), "CM - Characteristic1UUID not as packet based")
        XCTAssertTrue(cm.packetBasedCharacteristicUUIDS.contains(Characteristic4UUID), "CM - Characteristic4UUID not as packet based")
        XCTAssertTrue(cm.packetBasedCharacteristicUUIDS.contains(Characteristic6UUID), "CM - Characteristic6UUID not as packet based")
        XCTAssertEqual(cm.packetBasedCharacteristicUUIDS.count, 3, "CM - Incorrect number of packet based characteristics")
    }
    
}
