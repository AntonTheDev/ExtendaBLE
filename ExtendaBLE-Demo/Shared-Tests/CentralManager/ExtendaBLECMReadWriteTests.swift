//
//  ExtendableReadWriteTests.swift
//  ExtendaBLE
//
//  Created by Anton on 4/18/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import XCTest
import CoreBluetooth

@testable import ExtendaBLE

class ExtendableReadWriteTests: XCTestCase {
    
    override func setUp() { super.setUp() }
    override func tearDown() { super.tearDown() }
    
    func testCentralWriteReadPackets() {
        
        let central = ExtendaBLE.newCentralManager { (manager) in
            manager.addService(Service1UUIDKey) { (service) in
                
                service.addCharacteristic(Characteristic1UUIDKey) { (characteristic) in
                    characteristic.properties([.read, .write, .notify]).permissions([.readable, .writeable])
                    characteristic.packetsEnabled(true)
                }
            }
        }
        
        let testStringData = testValueString.data(using: .utf8)
        let packets = testStringData?.packetArray(withMTUSize: 101)
        
        let characteristic : CBMutableCharacteristic = CBMutableCharacteristic(type: Service1UUID,
                                                                               properties: [.read, .write, .notify],
                                                                               value: nil,
                                                                               permissions: [.readable, .writeable])
        
        central.peripheralCharacteristics[Peripheral1!] = [characteristic]
        
        central.write(data: testStringData!, toUUID: Service1UUIDKey) { (writtenData, error) in
            let valueString = String(data: writtenData!, encoding: .utf8)!
            XCTAssertTrue(testValueString == valueString, "Local Value Read Not Valid")
        }
        
        for packet in packets! {
            characteristic.value = packet
            central.receivedWriteResponse(forCharacteristic: characteristic, from: Peripheral1!)
        }
        
        XCTAssertTrue(central.activeWriteTransations[Peripheral1!]?.count == 0, "Read Transation was not cleared")
        
        central.read(characteristicUUID: Service1UUIDKey) { (returnedData, error) in
            let valueString = String(data: returnedData!, encoding: .utf8)!
            XCTAssertTrue(testValueString == valueString, "Local Value Read Not Valid")
        }
        
        for packet in packets! {
            characteristic.value = packet
            central.receivedReadResponse(forCharacteristic: characteristic, from: Peripheral1!, error: nil)
        }
        
        XCTAssertTrue(central.activeReadTransations[Peripheral1!]?.count == 0, "Read Transation was not cleared")
    }
}
