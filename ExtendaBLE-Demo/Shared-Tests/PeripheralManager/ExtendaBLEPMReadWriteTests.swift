//
//  ExtendablePMReadWriteTests.swift
//  ExtendaBLE-iOS-DemoTests
//
//  Created by Anton Doudarev on 11/9/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import XCTest
import CoreBluetooth

@testable import ExtendaBLE

class ExtendablePMReadWriteTests: XCTestCase {
    
    override func setUp() { super.setUp() }
    override func tearDown() { super.tearDown() }
    
    func testPeripheralWriteReadPackets() {
        
        let testStringData = testValueString.data(using: .utf8)
        let packets = testStringData?.packetArray(withMTUSize: 101)
        var characteristic : CBCharacteristic?
        
        let peripheral = ExtendaBLE.newPeripheralManager { (manager) in
            manager.addService(Service1UUIDKey) { (service) in
                
                service.addCharacteristic(Characteristic1UUIDKey) { (characteristic) in
                    
                    characteristic.properties([.read, .write, .notify]).permissions([.readable, .writeable])
                    characteristic.packetsEnabled(true)
                }
            }
        }
        
        for service in peripheral.registeredServices {
            if let tempCharacteristic = service.characteristics?.filter ({ $0.uuid.uuidString == Characteristic1UUIDKey.uppercased() }).first {
                characteristic = tempCharacteristic
            }
        }
        
        XCTAssertTrue(characteristic != nil, "Characteristic Not Found")
        
        for packet in packets! {
            if peripheral.processWriteRequest(packet: packet,
                                              from: Central1!,
                                              for: characteristic!,
                                              mtuSize: 101) {
                continue
            }
        }
        
        let localValue = peripheral.getLocalValue(for: characteristic!)
        XCTAssertTrue(localValue == testStringData, "Local Value Read Not Valid")
        
        let activeWriteTransactions = peripheral.activeWriteTransations[Central1!]
        XCTAssertTrue(activeWriteTransactions?.count == 0, "Read Transation was not cleared")
        
        var sendPackets = [Data]()
        
        repeat {
            let packet = peripheral.processReadRequest(from: Central1!, for: characteristic!, mtuSize: 101)
            sendPackets.append(packet!)
        } while(packets?.count != sendPackets.count)
        
        let data = Data.reconstructedData(withArray: sendPackets)
        let valueString = String(data: data!, encoding: .utf8)
        
        XCTAssertTrue(testValueString == valueString, "Local Value Read Not Valid")
        
        let activeReadTransactions = peripheral.activeReadTransations[Central1!]
        XCTAssertTrue(activeReadTransactions?.count == 0, "Read Transation was not cleared")
    }
}
