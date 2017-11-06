//
//  Data+BLEConvertable.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/30/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation

extension Data {

    public func int8Value(atIndex : Int) -> Int8? {
        let value =  subdata(in:atIndex..<1).withUnsafeBytes { (ptr: UnsafePointer<Int8>) -> Int8 in
            return ptr.pointee
        }
        return value
    }
    
    public func int16Value(atIndex : Int) -> Int16? {
        return Int16(bigEndian: subdata(in:atIndex..<2).withUnsafeBytes { $0.pointee })
    }
    
    public func int32Value(atIndex : Int) -> Int32? {
        return Int32(bigEndian: subdata(in:atIndex..<4).withUnsafeBytes { $0.pointee })
    }
    
    public func int64Value(atIndex : Int) -> Int64? {
        return Int64(bigEndian: subdata(in:atIndex..<8).withUnsafeBytes { $0.pointee })
    }
    
    public func uint8Value(atIndex : Int) -> UInt8? {
        let value =  subdata(in:atIndex..<1).withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> UInt8 in
            return ptr.pointee
        }
        return value
    }
    
    public func uint16Value(atIndex : Int) -> UInt16? {
        return UInt16(bigEndian: subdata(in:atIndex..<2).withUnsafeBytes { $0.pointee })
    }
    
    public func uint32Value(atIndex : Int) -> UInt32? {
        return UInt32(bigEndian: subdata(in:atIndex..<4).withUnsafeBytes { $0.pointee })
    }
    
    public func uint64Value(atIndex : Int) -> UInt64? {
        return UInt64(bigEndian: subdata(in:atIndex..<8).withUnsafeBytes { $0.pointee })
    }
    
    public func stringValue(atIndex : Int) -> String? {
        return String(data:  subdata(in:atIndex..<(count - atIndex)), encoding: .utf8)
    }
}

extension Data {
    
    public func int8Value(inRange range : Range<Data.Index>) -> Int8? {
        let value =  subdata(in:range).withUnsafeBytes { (ptr: UnsafePointer<Int8>) -> Int8 in
            return ptr.pointee
        }
        return value
    }
    
    public func int16Value(inRange range : Range<Data.Index>) -> Int16? {
        return Int16(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func int32Value(inRange range : Range<Data.Index>) -> Int32? {
        return Int32(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func int64Value(inRange range : Range<Data.Index>) -> Int64? {
        return Int64(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func uint8Value(inRange range : Range<Data.Index>) -> UInt8? {
        let value =  subdata(in:range).withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> UInt8 in
            return ptr.pointee
        }
        return value
    }
    
    public func uint16Value(inRange range : Range<Data.Index>) -> UInt16? {
        return UInt16(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func uint32Value(inRange range : Range<Data.Index>) -> UInt32? {
        return UInt32(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func uint64Value(inRange range : Range<Data.Index>) -> UInt64? {
        return UInt64(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func doubleValue(inRange range : Range<Data.Index>) -> Double? {
        let value = subdata(in:range).withUnsafeBytes { (ptr: UnsafePointer<Double>) -> Double in
            return ptr.pointee
        }
        
        return value
    }
    
    public func floatValue(inRange range : Range<Data.Index>) -> Float? {
        let value = subdata(in:range).withUnsafeBytes { (ptr: UnsafePointer<Float>) -> Float in
            return ptr.pointee
        }
        
        return value
    }
    
    public func stringValue(inRange range : Range<Data.Index>) -> String? {
        
        if range.lowerBound + range.upperBound > count {
            return nil
        }
        
        return String(data:  subdata(in:range), encoding: .utf8)
    }
}
