//
//  ADLogger.swift
//  TechBook
//
//  Created by Anton Doudarev on 9/25/15.
//  Copyright © 2015 Huge. All rights reserved.
//

import Foundation

public struct ExtendableLoggingConfig {
    static public var logLevel : LogLevel = .none
}

public enum LogLevel : Int {
    case none = 0
    case error = 1
    case warning = 2
    case info = 3
    case debug = 4
    case verbose = 5
}

func logError(_ logString:  String) {
    Log(.error, logString: logString)
}

func ad_logWarning(_ logString:  String) {
    Log(.warning, logString: logString)
}

func ad_logInfo(_ logString:  String) {
    Log(.info, logString: logString)
}

func ad_logDebug(_ logString:  String) {
    Log(.debug, logString: logString)
}

func ad_logVerbose(_ logString:  String) {
    Log(.verbose, logString: logString)
}

func ENTRY_LOG(functionName:  String = #function) {
    ad_logVerbose("ENTRY " + functionName)
}

func EXIT_LOG(functionName:  String = #function) {
    ad_logVerbose("EXIT " + functionName)
}

func Log(_ currentLogLevel: LogLevel, logString:  String) {
	if currentLogLevel.rawValue <= ExtendableLoggingConfig.logLevel.rawValue {
		let log = stringForLogLevel(ExtendableLoggingConfig.logLevel) + " - " + logString
		print(log)
	}
}

func stringForLogLevel(_ logLevel:  LogLevel) -> String {
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
