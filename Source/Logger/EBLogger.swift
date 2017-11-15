//
//  ADLogger.swift
//  TechBook
//
//  Created by Anton Doudarev on 9/25/15.
//  Copyright © 2015 Huge. All rights reserved.
//

import Foundation

public var publicLogString = ""

public struct ExtendableLoggingConfig {
    static public var logLevel : EBLogLevel = .none
}

public enum EBLogLevel : Int {
    case none = 0
    case error = 1
    case warning = 2
    case info = 3
    case debug = 4
    case verbose = 5
}

public func eb_logError(_ logString:  String) {
     EBLog(.error, logString: logString)
}

public func eb_logWarning(_ logString:  String) {
     EBLog(.warning, logString: logString)
}

public func eb_logInfo(_ logString:  String) {
     EBLog(.info, logString: logString)
}

public func eb_logDebug(_ logString:  String) {
     EBLog(.debug, logString: logString)
}

public func eb_logVerbose(_ logString:  String) {
     EBLog(.verbose, logString: logString)
}

public func ENTRY_LOG(functionName:  String = #function) {
    eb_logVerbose("ENTRY " + functionName)
}

public func EXIT_LOG(functionName:  String = #function) {
    eb_logVerbose("EXIT " + functionName)
}

public func EBLog(_ currentLogLevel: EBLogLevel, logString:  String) {
	if currentLogLevel.rawValue <= ExtendableLoggingConfig.logLevel.rawValue {
		let log = stringForLogLevel(ExtendableLoggingConfig.logLevel) + " - " + logString
		publicLogString += log
        print(log)
	}
}

public func stringForLogLevel(_ logLevel:  EBLogLevel) -> String {
    switch logLevel {
    case .debug:
        return "D"
    case .verbose:
        return "V"
    case .info:
        return "I"
    case .warning:
        return "W"
    case .error:
        return "E"
    case .none:
        return "NONE"
    }
}
