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
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    
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
