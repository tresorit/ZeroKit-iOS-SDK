import Foundation
import JavaScriptCore

protocol RandomProvider: class {
    func getRandom(bytes: UInt) throws -> Data
}

extension RandomProvider {
    func randomUInt32(max: UInt32) throws -> UInt32 {
        // max is inclusive
        if max == UInt32.max {
            return try randomUInt32()
        }
        
        let maxp1 = max + 1
        var r: UInt32 = 0
        
        repeat {
            r = try randomUInt32()
        } while r <= (UInt32.max % maxp1)
        
        return r % maxp1
    }
    
    func randomUInt32() throws -> UInt32 {
        let data = try self.getRandom(bytes: 4)
        return (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16) | (UInt32(data[2]) << 8) | UInt32(data[3])
    }
}

class SecRandomProvider: RandomProvider {
    func getRandom(bytes: UInt) throws -> Data {
        var retVal = Data(count: Int(bytes))
        let result = retVal.withUnsafeMutableBytes { (mutableBytes: UnsafeMutablePointer<UInt8>) -> Int32 in
            return SecRandomCopyBytes(kSecRandomDefault, retVal.count, mutableBytes)
        }
        if result != errSecSuccess {
            throw NSError(ZeroKitError.internalError, message: String(format: "Error getting sec random bytes, result: %d.", result))
        }
        return retVal
    }
}

class JsRandomProvider: RandomProvider {
    let context: JSContext
    let function: String
    
    init(context: JSContext, function: String) {
        self.context = context
        self.function = function
    }
    
    func getRandom(bytes: UInt) throws -> Data {
        let jsFunction = context.evaluateScript(function)
        let result = jsFunction?.call(withArguments: [bytes])
        if let b64Str = result?.toString(),
            let data = Data(base64Encoded: b64Str) {
            return data
        }
        throw NSError(ZeroKitError.internalError, message: "Error getting JS random bytes.")
    }
}
