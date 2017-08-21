import UIKit

class Crypto {
    class func aesGcmEncrypt(plainData: Data, key: Data, iv: Data, adata: Data, tagLength: Int) -> Data? {
        var cipherData = Data(count: plainData.count)
        var tag = Data(count: tagLength)
        
        func encrypt(keyPtr: UnsafePointer<UInt8>, ivPtr: UnsafePointer<UInt8>, adataPtr: UnsafePointer<UInt8>, plainDataPtr: UnsafePointer<UInt8>, cipherDataPtr: UnsafeMutablePointer<UInt8>, tagPtr: UnsafeMutablePointer<UInt8>) -> Int32 {
            switch key.count * 8 {
            case 128:
                return encryptAes128GcmRaw(keyPtr, key.count, ivPtr, iv.count, adataPtr, adata.count, plainDataPtr, plainData.count, cipherDataPtr, cipherData.count, tagPtr, tag.count)
            case 256:
                return encryptAes256GcmRaw(keyPtr, key.count, ivPtr, iv.count, adataPtr, adata.count, plainDataPtr, plainData.count, cipherDataPtr, cipherData.count, tagPtr, tag.count)
            default:
                return -1
            }
        }
        
        var result: Int32 = 0
        
        plainData.withUnsafeBytes { (plainDataPtr: UnsafePointer<UInt8>) -> Void in
            key.withUnsafeBytes { (keyPtr: UnsafePointer<UInt8>) -> Void in
                iv.withUnsafeBytes { (ivPtr: UnsafePointer<UInt8>) -> Void in
                    adata.withUnsafeBytes { (adataPtr: UnsafePointer<UInt8>) -> Void in
                        cipherData.withUnsafeMutableBytes { (cipherDataPtr: UnsafeMutablePointer<UInt8>) -> Void in
                            tag.withUnsafeMutableBytes { (tagPtr: UnsafeMutablePointer<UInt8>) -> Void in
                                result = encrypt(keyPtr: keyPtr, ivPtr: ivPtr, adataPtr: adataPtr, plainDataPtr: plainDataPtr, cipherDataPtr: cipherDataPtr, tagPtr: tagPtr)
                            }
                        }
                    }
                }
            }
        }
        
        if result != 0 {
            return nil
        }
        
        cipherData.append(tag)
        return cipherData
    }
    
    class func aesGcmDecrypt(cipherData: Data, key: Data, iv: Data, adata: Data, tagLength: Int) -> Data? {
        let cipherBytes = cipherData.subdata(in: cipherData.startIndex ..< cipherData.endIndex.advanced(by: -tagLength))
        let tag = cipherData.subdata(in: cipherData.endIndex.advanced(by: -tagLength) ..< cipherData.endIndex)
        var plainData = Data(count: cipherBytes.count)
        
        func decrypt(keyPtr: UnsafePointer<UInt8>, ivPtr: UnsafePointer<UInt8>, adataPtr: UnsafePointer<UInt8>, cipherBytesPtr: UnsafePointer<UInt8>, tagPtr: UnsafePointer<UInt8>, plainDataPtr: UnsafeMutablePointer<UInt8>) -> Int32 {
            switch key.count * 8 {
            case 128:
                return decryptAes128GcmRaw(keyPtr, key.count, ivPtr, iv.count, adataPtr, adata.count, cipherBytesPtr, cipherBytes.count, tagPtr, tag.count, plainDataPtr, plainData.count)
            case 256:
                return decryptAes256GcmRaw(keyPtr, key.count, ivPtr, iv.count, adataPtr, adata.count, cipherBytesPtr, cipherBytes.count, tagPtr, tag.count, plainDataPtr, plainData.count)
            default:
                return -1
            }
        }
        
        var result: Int32 = 1
        
        cipherBytes.withUnsafeBytes { (cipherBytesPtr: UnsafePointer<UInt8>) -> Void in
            tag.withUnsafeBytes { (tagPtr: UnsafePointer<UInt8>) -> Void in
                key.withUnsafeBytes { (keyPtr: UnsafePointer<UInt8>) -> Void in
                    iv.withUnsafeBytes { (ivPtr: UnsafePointer<UInt8>) -> Void in
                        adata.withUnsafeBytes { (adataPtr: UnsafePointer<UInt8>) -> Void in
                            plainData.withUnsafeMutableBytes { (plainDataPtr: UnsafeMutablePointer<UInt8>) -> Void in
                                result = decrypt(keyPtr: keyPtr, ivPtr: ivPtr, adataPtr: adataPtr, cipherBytesPtr: cipherBytesPtr, tagPtr: tagPtr, plainDataPtr: plainDataPtr)
                            }
                        }
                    }
                }
            }
        }
        
        if result != 1 {
            return nil
        }
        
        return plainData
    }
}
