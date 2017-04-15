//
//  CentralManager+Delegates.swift
//  
//
//  Created by Anton on 4/15/17.
//
//

import Foundation
import CoreBluetooth


// MARK: - CBCentralManagerDelegate

extension EBCentralManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        operationQueue.async { [unowned self] in
            self.respondToManagerStateChange(central)
        }
    }
    
    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String : Any],
                               rssi RSSI: NSNumber) {
        operationQueue.async { [unowned self] in
            self.connect(to : peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        operationQueue.async { [unowned self] in
            self.pairPeripheral(peripheral.identifier)
            self.discoverRegisteredServices(on: peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        operationQueue.async { [unowned self] in
            self.disconnect(from : peripheral.identifier, error)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        operationQueue.async { [unowned self] in
            self.disconnect(from : peripheral.identifier, error)
        }
    }
    
    /*
     #if os(iOS) || os(tvOS)
     public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
     
     }
     #endif
     */
}

// MARK: - CBPeripheralDelegate

extension EBCentralManager: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        operationQueue.async { [unowned self] in
            self.handleServicesDiscovered(for : peripheral, error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        operationQueue.async { [unowned self] in
            self.discoveredCharactetistics(forService : service, from : peripheral, error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        dataQueue.async { [unowned self] in
            self.receivedReadResponse(forCharacteristic: characteristic, from: peripheral.identifier, error: error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        dataQueue.async { [unowned self] in
            self.receivedWriteResponse(forCharacteristic : characteristic, from : peripheral.identifier)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        dataQueue.async { [unowned self] in
            self.handleNotificationStateUpdate(peripheral, characteristic, error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        Log(.debug, logString: "didDiscoverIncludedServicesFor \(peripheral) \(service)")
    }
    
    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        Log(.debug, logString: "peripheralDidUpdateName \(peripheral)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        Log(.debug, logString: "didModifyServices \(peripheral)")
    }
    
    public func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
        Log(.debug, logString: "peripheralDidUpdateRSSI \(peripheral)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        Log(.debug, logString: "didReadRSSI \(peripheral)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        Log(.debug, logString: "didDiscoverDescriptorsFor uuid: \(characteristic.uuid), value: \(String(describing: characteristic.value))")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        Log(.debug, logString: "didUpdateValueFor uuid: \(descriptor.uuid), value: \(String(describing: descriptor.value))")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        Log(.debug, logString: "didWriteValueFor descriptor uuid: \(descriptor.uuid), value: \(String(describing: descriptor.value))")
    }
    
}

