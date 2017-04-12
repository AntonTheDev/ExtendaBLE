//
//  Data+BLE.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/27/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation

let packetHeaderSize : Int16 = 4

extension Data {
    
    var packetIndex : Int {
        get {
            /*
            if count < 4 {
                print("Chunk Index Not Found in \(self)")
                return 0
            }
            */
            return bytes(0, 2) as Int
        }
    }
    
    var totalPackets : Int {
        get {
            /*
            if count < 4 {
                print("Chunk Total Not Found in \(self)")
                return 0
            }
            */
            return bytes(2, 2) as Int }
    }
    
    internal func headerData(packetIndex : Int16, totalPackets : Int16) -> Data {
        let messageData = NSMutableData()
        messageData.appendInt16(packetIndex)
        messageData.appendInt16(totalPackets)
        return messageData as Data
    }
}

extension Data {

    func packetArray(withMTUSize mtuSize : Int16) -> [Data] {
        
        let packetSize = mtuSize - packetHeaderSize
        
        let length = Int16(self.count)
        var offset = Int16(0)
        
        let totalPackets  = (length / packetSize) + (length % packetSize > 0 ? 1 : 0)
        var currentCount  = Int16(0)
        
        var packetArray = [Data]()
        
        repeat {
            currentCount = currentCount + 1
            
            let currentPacketSize = ((length - offset) > packetSize) ? packetSize : (length - offset)
            let packet = subdata(in:Int(offset)..<Int(offset + currentPacketSize))
            
            let messageData = NSMutableData()
            messageData.append(headerData(packetIndex : currentCount, totalPackets : totalPackets))
            messageData.append(packet)
        
            packetArray.append(messageData as Data)
            
            offset += currentPacketSize
            
        } while (offset < length)

        return packetArray
    }
    
    static func reconstructedData(withArray dataArray : [Data]) -> Data? {
        
        var orderedPacketArray = Array<Data?>(repeating: nil, count: dataArray.count)
        
        for dataItem in dataArray {
            let packetIndex = dataItem.packetIndex
            orderedPacketArray[Int(packetIndex - 1)] = dataItem.subdata(in: Int(packetHeaderSize)..<(dataItem.count))
        }
        
        let reconstructedData = NSMutableData()
        
        for packetData in orderedPacketArray {
            if let data = packetData {
                reconstructedData.append(data)
            }
        }
        
        return reconstructedData as Data
    }
}

extension NSMutableData {
    
    func appendInt8(value : Int8) {
        var val = value
        self.append(&val, length: MemoryLayout.size(ofValue: val))
    }
    
    func appendInt16(_ value : Int16) {
        var val = value.bigEndian
        self.append(&val, length:  MemoryLayout<UInt16>.size)
    }
    
    func appendInt32(_ value : Int32) {
        var val = value.bigEndian
        self.append(&val, length: MemoryLayout<UInt32>.size)
    }
    
    func appendInt64(_ value : Int64) {
        var val = value.bigEndian
        self.append(&val, length: MemoryLayout<UInt64>.size)
    }
    
    func appendString(value : String) {
        value.withCString {
            self.append($0, length: Int(strlen($0)) + 1)
        }
    }
}

extension Data {
    
    public func bytes(_ range : Range<Data.Index>) -> Int {
        /*
        if (range.lowerBound + range.upperBound) > count {
            print("Byte Range outside of bounds \(self)")
            return 0
        }
        */
        return bytes(range.lowerBound, range.upperBound)
    }

    internal func bytes(_ start: Int, _ length: Int) -> Int {
        
        let lowerBound = start * 8
        let upperBound = length * 8
        
        let bytesLength = self.count
        var bytesArray  = [UInt8](repeating: 0, count: bytesLength)
        (self as NSData).getBytes(&bytesArray, length: bytesLength)
        let  bytes      = bytesArray
        
        let range = lowerBound..<(lowerBound + upperBound)
        
        var positions = [Int]()
        
        for position in range.lowerBound..<range.upperBound {
            positions.append(position)
        }
        
        return positions.reversed().enumerated().reduce(0) {
            
            let position = $1.element
            
            let byteSize        = 8
            let bytePosition    = position / byteSize
            let bitPosition     = 7 - (position % byteSize)
            let byte            = Int(bytes[bytePosition])
            
            return $0 + (((byte >> bitPosition) & 0x01) << $1.offset)
        }
    }
}


