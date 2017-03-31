//
//  EBTransaction.swift
//  CameraApp
//
//  Created by Anton Doudarev on 3/29/17.
//  Copyright © 2017 Anton Doudarev. All rights reserved.
//

import Foundation
import CoreBluetooth

public typealias EBTransactionCallback = ((_ data: Data, _ error: Error?) -> Void)

public class Transaction {
    
    var data : Data?
    var responseCount : Int = 0
    var chunks : [Data] = [Data]()
    var characteristic : CBCharacteristic?
    var completion : EBTransactionCallback?
    
    var isComplete : Bool {
        get {
            return chunks.count == responseCount && responseCount != 0
        }
    }
    
    var reconstructedValue : Data {
        get {  return  Data.reconstructedData(withArray: chunks)! }
    }
}
