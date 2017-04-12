//
//  Data+BLEConvertable.swift
//  ExtendaBLE
//
//  Created by Anton Doudarev on 3/30/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation

extension Data {

    public func int8Value(_ range : Range<Data.Index>) -> Int8? {
        let value =  subdata(in:range).withUnsafeBytes { (ptr: UnsafePointer<Int8>) -> Int8 in
            return ptr.pointee
        }
        return value
    }
    
    public func int16Value(_ range : Range<Data.Index>) -> Int16? {
        return Int16(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func int32Value(_ range : Range<Data.Index>) -> Int32? {
        return Int32(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func int64Value(_ range : Range<Data.Index>) -> Int64? {
        return Int64(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func uint8Value(_ range : Range<Data.Index>) -> UInt8? {
        let value =  subdata(in:range).withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> UInt8 in
            return ptr.pointee
        }
        return value
    }
    
    public func uint16Value(_ range : Range<Data.Index>) -> UInt16? {
        return UInt16(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func uint32Value(_ range : Range<Data.Index>) -> UInt32? {
        return UInt32(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func uint64Value(_ range : Range<Data.Index>) -> UInt64? {
        return UInt64(bigEndian: subdata(in:range).withUnsafeBytes { $0.pointee })
    }
    
    public func doubleValue(_ range : Range<Data.Index>) -> Double? {
        let value = subdata(in:range).withUnsafeBytes { (ptr: UnsafePointer<Double>) -> Double in
            return ptr.pointee
        }
        
        return value
    }
    
    public func floatValue(_ range : Range<Data.Index>) -> Float? {
        let value = subdata(in:range).withUnsafeBytes { (ptr: UnsafePointer<Float>) -> Float in
            return ptr.pointee
        }
        
        return value
    }
    
    public func stringValue(_ range : Range<Data.Index>) -> String? {
        
        if range.lowerBound + range.upperBound > count {
            return nil
        }
        
        return String(data:  subdata(in:range), encoding: .utf8)
    }

}
