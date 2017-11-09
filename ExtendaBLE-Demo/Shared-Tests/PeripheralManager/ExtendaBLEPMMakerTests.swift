//
//  ExtendaBLETests.swift
//  ExtendaBLETests
//
//  Created by Anton on 3/30/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import XCTest
import CoreBluetooth

@testable import ExtendaBLE

class ExtendaBLEMakerTests: XCTestCase {
    
    override func setUp() { super.setUp() }
    override func tearDown() { super.tearDown() }
    
    /// Test PeripheralManager Configuration
    func testPeripheralConfig() {
        
        let pr = ExtendaBLE.newPeripheralManager { (peripheral) in
            peripheral.localName("Test Peripheral")
            peripheral.onStateChange { (state) in
            }.onDidStartAdvertising { (success, error) in
            }
        }
    
        XCTAssertEqual(pr.localName, "Test Peripheral", "PR - supportMutiplePeripherals misconfigured")
        XCTAssertNotNil(pr.stateChangeCallBack, "PR - stateChangeCallBack callback missing")
        XCTAssertNotNil(pr.didStartAdvertisingCallBack, "PR - didStartAdvertisingCallBack callback missing")
    }
    
    /// Test Service Configuration on the Central Manager
    func testPeripheralServiceConfig() {
        
        let pm = ExtendaBLE.newPeripheralManager { (manager) in
            
            manager.addService(Service1UUIDKey) {(service) in
                
                service.addCharacteristic(Characteristic1UUIDKey) { (characteristic) in }
                    .addCharacteristic(Characteristic2UUIDKey) { (characteristic) in }
                    .addCharacteristic(Characteristic3UUIDKey) { (characteristic) in }
                
                XCTAssertTrue(service.primary,"PSM - Service did not default to primary" )
                XCTAssertEqual(service.characteristics.count, 3, "PSM - Service Did Not Register Correct Number of Characteristics")
                XCTAssertEqual(service.packetBasedCharacteristicUUIDS.count, 0, "PSM - Incorrect Number of Packet Based Characteristics")
                
                }.addService(Service2UUIDKey) { (service) in
                    service.primary(false)
                    
                    service.addCharacteristic(Characteristic4UUIDKey) { (characteristic) in }
                        .addCharacteristic(Characteristic6UUIDKey) { (characteristic) in
                    }
                    
                    XCTAssertEqual(service.characteristics.count, 2, "PSM - Service Did Not Register Correct Number of Characteristics")
                    XCTAssertTrue(service.primary == false ,"PSM - Service Should Not Be Primary" )
                    XCTAssertEqual(service.packetBasedCharacteristicUUIDS.count, 0, "PSM - Incorrect Number of Packet Based Characteristics")
            }
        }
        
        let service1 = pm.registeredServices.filter({ $0.uuid == Service1UUID }).first
        let service2 = pm.registeredServices.filter({ $0.uuid == Service2UUID }).first
        
        XCTAssertNotNil(service1, "PR - Failed to Register Service")
        XCTAssertNotNil(service2, "PR - Failed to Register Service")
        
        XCTAssertTrue(service1!.isPrimary, "PR - Failed Setting Primary Key on Service")
        XCTAssertFalse(service2!.isPrimary, "PR - Failed Setting Primary Key on Service")
        
        XCTAssertEqual(service1!.characteristics!.count, 3, "PR - Service Did Not Register Correct Number of Characteristics")
        XCTAssertEqual(service2!.characteristics!.count, 2, "PR - Service Did Not Register Correct Number of Characteristics")
    }
    
    
    /// Characteristic Configuration on the Services Registered for the Central Manager
    func testPeripheralCharacteristicConfig() {
        
        let pm = ExtendaBLE.newPeripheralManager { (manager) in
            
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
        
        let service1 = pm.registeredServices.filter({ $0.uuid == Service1UUID }).first
        // let service2 = pm.registeredServices.filter({ $0.uuid == Service2UUID }).first
        
        if let char1 = service1?.characteristics?.filter({ $0.uuid == Characteristic1UUID }).first {
            XCTAssertTrue(char1.properties.contains(.read), "CCRM - Characteristic Registered Incorrect properties")
            XCTAssertTrue(!char1.properties.contains(.write), "CCRM - Characteristic Registered Incorrect properties")
            XCTAssertTrue(!char1.properties.contains(.notify), "CCRM - Characteristic Registered Incorrect properties")
        }
        
        if let char2 = service1?.characteristics?.filter({ $0.uuid == Characteristic2UUID }).first {
            XCTAssertTrue(char2.properties.contains(.write), "CCRM - Characteristic Registered Incorrect properties")
            XCTAssertTrue(!char2.properties.contains(.read), "CCRM - Characteristic Registered Incorrect properties")
            XCTAssertTrue(!char2.properties.contains(.notify), "CCRM - Characteristic Registered Incorrect properties")
            
            XCTAssertNil(pm.registeredCharacteristicCallbacks[char2.uuid], "CCRM - Characteristic updateCallback callback missing")
        }
        
        if let char3 = service1?.characteristics?.filter({ $0.uuid == Characteristic3UUID }).first {
            XCTAssertTrue(char3.properties.contains(.read), "CCRM - Characteristic Registered Incorrect properties")
            XCTAssertTrue(char3.properties.contains(.write), "CCRM - Characteristic Registered Incorrect properties")
            XCTAssertTrue(char3.properties.contains(.notify), "CCRM - Characteristic Registered Incorrect properties")
            XCTAssertTrue(!char3.properties.contains(.writeWithoutResponse), "SM - Service Registered Incorrect properties")
            XCTAssertTrue(!char3.properties.contains(.indicate), "CCRM - Characteristic Registered Incorrect properties")
           
            XCTAssertNotNil(pm.registeredCharacteristicCallbacks[char3.uuid], "CCRM - Characteristic updateCallback callback missing")
        }
        
        
        XCTAssertEqual(pm.registeredServices.count, 3, "CM - Invalid Number of Services (Missing MTU Service?)")
        XCTAssertTrue(pm.packetBasedCharacteristicUUIDS.contains(Characteristic1UUID), "CM - Characteristic1UUID not as packet based")
        XCTAssertTrue(pm.packetBasedCharacteristicUUIDS.contains(Characteristic4UUID), "CM - Characteristic4UUID not as packet based")
        XCTAssertTrue(pm.packetBasedCharacteristicUUIDS.contains(Characteristic6UUID), "CM - Characteristic6UUID not as packet based")
        XCTAssertEqual(pm.packetBasedCharacteristicUUIDS.count, 3, "CM - Incorrect number of packet based characteristics")
    }
}
