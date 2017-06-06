//
//  Log.swift
//  ZeroKit
//
//  Created by László Agárdi on 2017. 05. 29..
//  Copyright © 2017. Tresorit Kft. All rights reserved.
//

import Foundation

public enum ZeroKitLogLevel: UInt8 {
    case error
    case warning
    case info
    case debug
    case verbose
    
    var stringValue: String {
        switch self {
        case .error:
            return "ERROR"
        case .warning:
            return "WARNING"
        case .info:
            return "INFO"
        case .debug:
            return "DEBUG"
        case .verbose:
            return "VERBOSE"
        }
    }
    
    init(jsLogLevel: String) {
        switch jsLogLevel {
        case "error":
            self.init(rawValue: ZeroKitLogLevel.error.rawValue)!
        case "warn":
            self.init(rawValue: ZeroKitLogLevel.warning.rawValue)!
        case "info":
            self.init(rawValue: ZeroKitLogLevel.info.rawValue)!
        case "log":
            self.init(rawValue: ZeroKitLogLevel.debug.rawValue)!
        default:
            self.init(rawValue: ZeroKitLogLevel.verbose.rawValue)!
        }
    }
}

class Log: NSObject {
    static private var levelInner = ZeroKitLogLevel.warning
    
    class var level: ZeroKitLogLevel {
        get {
            var retVal: ZeroKitLogLevel!
            zk_synchronized {
                retVal = self.levelInner
            }
            return retVal
        }
        set {
            zk_synchronized {
                self.levelInner = newValue
            }
        }
    }
    
    class func e(_ format: String, _ args: CVarArg...) {
        log(level: .error, format: format, args: args)
    }
    
    class func w(_ format: String, _ args: CVarArg...) {
        log(level: .warning, format: format, args: args)
    }
    
    class func i(_ format: String, _ args: CVarArg...) {
        log(level: .info, format: format, args: args)
    }
    
    class func d(_ format: String, _ args: CVarArg...) {
        log(level: .debug, format: format, args: args)
    }
    
    class func v(_ format: String, _ args: CVarArg...) {
        log(level: .verbose, format: format, args: args)
    }
    
    class func log(level: ZeroKitLogLevel, format: String, args: CVarArg...) {
        log(level: level, format: format, args: args)
    }
    
    class func log(level: ZeroKitLogLevel, format: String, args: [CVarArg]) {
        if level.rawValue <= self.level.rawValue {
            let message = String(format: format, arguments: args)
            NSLog("ZeroKit[%@]: %@", level.stringValue, message)
        }
    }
}
