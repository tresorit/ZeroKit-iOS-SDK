import JavaScriptCore

@objc protocol CryptoJSExport: JSExport {
    func cryptoSecureRandomBytes(_ len: Int) -> NSString?
    func aesGcmEncrypt(_ data: NSString, _ key: NSString, _ iv: NSString, _ adata: NSString, _ tagLength: Int) -> NSString?
    func aesGcmDecrypt(_ data: NSString, _ key: NSString, _ iv: NSString, _ adata: NSString, _ tagLength: Int) -> NSString?
    func hmacSha256(_ data: NSString, _ key: NSString) -> NSString?
    func pbkdf2HmacSha256(_ password: NSString, _ salt: NSString, _ iterations: UInt32, _ size: Int) -> NSString?
    func pbkdf2HmacSha512(_ password: NSString, _ salt: NSString, _ iterations: UInt32, _ size: Int) -> NSString?
    func sha256(_ data: NSString) -> NSString?
    func sha512(_ data: NSString) -> NSString?
    func scrypt(_ password: NSString, _ salt: NSString, _ N: NSNumber, _ r: NSNumber, _ p: NSNumber, _ keySize: Int) -> NSString?
}

class Crypto: NSObject, CryptoJSExport {
    
    func cryptoSecureRandomBytes(_ len: Int) -> NSString? {
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        defer {
            buf.deallocate(capacity: len)
        }
        if cryptoRandomBytes(buf, len) == 0 {
            return Data(bytes: UnsafeRawPointer(buf), count: len).base64EncodedString() as NSString
        }
        fatalError("ZeroKit could not get crypto random bytes")
    }

    func aesGcmEncrypt(_ data: NSString, _ key: NSString, _ iv: NSString, _ adata: NSString, _ tagLength: Int) -> NSString? {
        let cipherTextLen = data.length + 1
        var cipherTextBuffer = Data(count: cipherTextLen)
        
        let tagBufferLen = tagLength * 2 + 1
        var tagBuffer = Data(count: tagBufferLen)
        
        var result = Int32(0)
        
        cipherTextBuffer.withUnsafeMutableBytes { (cipherTextPtr: UnsafeMutablePointer<Int8>) -> Void in
            tagBuffer.withUnsafeMutableBytes { (tagPtr: UnsafeMutablePointer<Int8>) -> Void in
                switch key.length * 4 {
                case 128:
                    result = encryptAes128Gcm(key.utf8String, iv.utf8String, adata.utf8String, data.utf8String, cipherTextPtr, cipherTextLen, tagPtr, tagLength)
                case 256:
                    result = encryptAes256Gcm(key.utf8String, iv.utf8String, adata.utf8String, data.utf8String, cipherTextPtr, cipherTextLen, tagPtr, tagLength)
                default:
                    result = -1
                }
            }
        }
        
        if result != 0 {
            return nil
        }
        
        // Remove trailing NULL characters
        cipherTextBuffer.removeLast()
        tagBuffer.removeLast()
        
        var cipherData = Data()
        cipherData.append(cipherTextBuffer)
        cipherData.append(tagBuffer)
        
        return String(data: cipherData, encoding: .utf8)! as NSString
    }

    func aesGcmDecrypt(_ data: NSString, _ key: NSString, _ iv: NSString, _ adata: NSString, _ tagLength: Int) -> NSString? {
        let cipherText = data.substring(to: data.length - tagLength * 2) as NSString
        let tag = data.substring(from: cipherText.length) as NSString
        
        let plainTextBufferLen = cipherText.length + 1
        var plainTextBuffer = Data(count: plainTextBufferLen)
        
        var result = Int32(1)
        
        plainTextBuffer.withUnsafeMutableBytes { (plainTextPtr: UnsafeMutablePointer<Int8>) -> Void in
            switch key.length * 4 {
            case 128:
                result = decryptAes128Gcm(key.utf8String, iv.utf8String, adata.utf8String, cipherText.utf8String, tag.utf8String, plainTextPtr, plainTextBufferLen)
            case 256:
                result = decryptAes256Gcm(key.utf8String, iv.utf8String, adata.utf8String, cipherText.utf8String, tag.utf8String, plainTextPtr, plainTextBufferLen)
            default:
                result = -1
            }
        }
        
        if result != 1 {
            return nil
        }
        
        plainTextBuffer.removeLast() // Trailing NULL char
        return String(data: plainTextBuffer, encoding: .utf8)! as NSString
    }

    func hmacSha256(_ data: NSString, _ key: NSString) -> NSString? {
        var buffer = Data(count: 65)
        
        let result = buffer.withUnsafeMutableBytes { (ptr: UnsafeMutablePointer<Int8>) -> Int32 in
            return calculateHmacSha256(key.utf8String, data.utf8String, ptr, buffer.count)
        }
        
        if result != 0 {
            return nil
        }
        
        buffer.removeLast() // Trailing NULL char
        return String(data: buffer, encoding: .utf8)! as NSString
    }

    func pbkdf2HmacSha256(_ password: NSString, _ salt: NSString, _ iterations: UInt32, _ size: Int) -> NSString? {
        return self.pbkdf2HmacSha(password, salt, iterations, size, .sha256)
    }

    func pbkdf2HmacSha512(_ password: NSString, _ salt: NSString, _ iterations: UInt32, _ size: Int) -> NSString? {
        return self.pbkdf2HmacSha(password, salt, iterations, size, .sha512)
    }

    private enum ShaMode {
        case sha256
        case sha512
    }
    
    private func pbkdf2HmacSha(_ password: NSString, _ salt: NSString, _ iterations: UInt32, _ size: Int, _ shaMode: ShaMode) -> NSString? {
        var buffer = Data(count: size * 2 + 1)
        
        let result = buffer.withUnsafeMutableBytes { (ptr: UnsafeMutablePointer<Int8>) -> Int32 in
            switch shaMode {
            case .sha256:
                return derivePbkdf2HmacSha256(password.utf8String, salt.utf8String, iterations, ptr, size)
            case .sha512:
                return derivePbkdf2HmacSha512(password.utf8String, salt.utf8String, iterations, ptr, size)
            }
        }
        
        if result != 0 {
            return nil
        }
        
        buffer.removeLast() // Trailing NULL char
        return String(data: buffer, encoding: .utf8)! as NSString
    }
    
    func sha256(_ data: NSString) -> NSString? {
        return sha(data, .sha256)
    }

    func sha512(_ data: NSString) -> NSString? {
        return sha(data, .sha512)
    }
    
    private func sha(_ data: NSString, _ shaMode: ShaMode) -> NSString? {
        var buffer: Data
        var result: Int32
        
        switch shaMode {
        case .sha256:
            buffer = Data(count: 65)
            result = buffer.withUnsafeMutableBytes({ (ptr: UnsafeMutablePointer<Int8>) -> Int32 in
                return calculateSha256(data.utf8String, ptr, buffer.count)
            })
        case .sha512:
            buffer = Data(count: 129)
            result = buffer.withUnsafeMutableBytes({ (ptr: UnsafeMutablePointer<Int8>) -> Int32 in
                return calculateSha512(data.utf8String, ptr, buffer.count)
            })
        }
        
        if result != 0 {
            return nil
        }
        
        buffer.removeLast() // Trailing NULL char
        return String(data: buffer, encoding: .utf8)! as NSString
    }
    
    func scrypt(_ password: NSString, _ salt: NSString, _ N: NSNumber, _ r: NSNumber, _ p: NSNumber, _ keySize: Int) -> NSString? {
        var key = Data(count: keySize * 2 + 1)
        
        let result = key.withUnsafeMutableBytes { (ptr: UnsafeMutablePointer<Int8>) -> Int32 in
            return deriveScrypt(password.utf8String, salt.utf8String, N.uint64Value, r.uint64Value, p.uint64Value, ptr, keySize)
        }
        
        if result != 0 {
            return nil
        }
        
        key.removeLast() // Trailing NULL char
        return String(data: key, encoding: .utf8)! as NSString
    }
}
