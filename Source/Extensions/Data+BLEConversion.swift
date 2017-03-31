//
//  Data+BLEConvertable.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/30/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation

extension Data {

    public func int8Value(_ range : Range<Data.Index>) -> Int8? {
        return numericValue(range)
    }
    
    public func int16Value(_ range : Range<Data.Index>) -> Int16? {
        return numericValue(range)
    }
    
    public func int32Value(_ range : Range<Data.Index>) -> Int32? {
        return numericValue(range)
    }
    
    public func int64Value(_ range : Range<Data.Index>) -> Int64? {
        return numericValue(range)
    }
    
    public func uint8Value(_ range : Range<Data.Index>) -> UInt8? {
        return numericValue(range)
    }
    
    public func uint16Value(_ range : Range<Data.Index>) -> UInt16? {
        return numericValue(range)
    }
    
    public func uint32Value(_ range : Range<Data.Index>) -> UInt32? {
        return numericValue(range)
    }
    
    public func uint64Value(_ range : Range<Data.Index>) -> UInt64? {
        return numericValue(range)
    }
    
    
    public func doubleValue(_ range : Range<Data.Index>) -> Double? {
        return numericValue(range)
    }
    
    public func floatValue(_ range : Range<Data.Index>) -> Float? {
        return numericValue(range)
    }
    
    public func stringValue(_ range : Range<Data.Index>) -> String? {
        return String(data:  subdata(in:range), encoding: .utf8)
    }

    private func numericValue<T> (_ range : Range<Data.Index>) -> T? {
        let value =  subdata(in:range).withUnsafeBytes { (ptr: UnsafePointer<T>) -> T in
            return ptr.pointee
        }
        return value
    }
}
