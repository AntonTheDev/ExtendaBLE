//
//  EBTransaction.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/29/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public typealias EBTransactionCallback = ((_ data: Data?, _ error: Error?) -> Void)

public enum TransactionDirection : Int {
    case centralToPeripheral
    case peripheralToCentral
}

public enum TransactionType : Int {
    case read
    case readPackets
    case write
    case writePackets
}

public class Transaction {
    
    var characteristic : CBCharacteristic?

    internal var direction      : TransactionDirection
    internal var type           : TransactionType
    internal var mtuSize        : Int16
    internal var totalPackets   : Int = 0
    internal var completion     : EBTransactionCallback?
    
    internal var activeResponseCount : Int = 0
    
    var dataPackets : [Data] = [Data]()
    
    var data : Data? {
        get {
            if type == .readPackets || type == .writePackets {
                return  Data.reconstructedData(withArray: dataPackets)!
            } else {
                
                if let singlePacket = dataPackets.first {
                    return singlePacket
                }
                return nil
            }
        }
        set {
            if type == .readPackets || type == .writePackets {
                dataPackets = newValue?.packetArray(withMTUSize: mtuSize) ?? [Data]()
                totalPackets = newValue?.packetArray(withMTUSize: mtuSize).count ?? 1
            } else {
                if let value = newValue {
                    dataPackets = [value]
                } else {
                    dataPackets = [Data]()
                }
            }
        }
    }
    
    public required init(_ type : TransactionType ,
                         _ direction : TransactionDirection,
                         characteristic : CBCharacteristic? = nil,
                         mtuSize : Int16 = 23,
                         completion : EBTransactionCallback? = nil) {
        
        self.direction = direction
        self.type = type
        self.mtuSize = mtuSize
        self.characteristic = characteristic
        self.completion = completion
        
        if type != .writePackets && type != .readPackets {
             totalPackets = 1
        }
    }

    func processTransaction() {
        activeResponseCount = activeResponseCount + 1
    }
    
    func nextPacket() -> Data? {
        if activeResponseCount > dataPackets.count {
            return nil
        }
        
        return dataPackets[activeResponseCount - 1]
    }
    
    func appendPacket(_ dataPacket : Data?) {
        
        guard let dataPacket = dataPacket else {
            return
        }
        
        if type == .writePackets || type == .readPackets {
            totalPackets = dataPacket.totalPackets
        }
        
        dataPackets.append(dataPacket)
    }
    
    var isComplete : Bool {
        get {
            if type == .readPackets {
                return totalPackets == activeResponseCount
            } else if type == .writePackets {
                return totalPackets == activeResponseCount
            }
            
            return (activeResponseCount == 1)
        }
    }
}
