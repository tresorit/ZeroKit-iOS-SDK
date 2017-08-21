import Foundation

class CipherData {
    let formatVersion: UInt
    let keyVersion: UInt
    let tresorId: String
    let adata: Data
    let iv: Data
    let cipherBytes: Data
    
    init(cipherData: Data) throws {
        let lebData = Leb128InData(data: cipherData)
        formatVersion = decodeUnsignedLEB(lebData)
        if formatVersion != 1 {
            throw NSError(ZeroKitError.badInput, message: "Tresor ID format error.")
        }
        keyVersion = decodeUnsignedLEB(lebData)
        
        let index1 = cipherData.startIndex.advanced(by: lebData.index)  // start of tresorId
        let index2 = index1.advanced(by: 24)                            // end of tresorId
        let index3 = index2.advanced(by: 1)                             // end of null terminating byte of tresorId string, start of iv
        let index4 = index3.advanced(by: 16)                            // end of iv, start of cipher bytes
        let index5 = cipherData.endIndex
        
        if let tresorIdString = String(data: cipherData.subdata(in: index1 ..< index2), encoding: .utf8) {
            tresorId = tresorIdString
        } else {
            throw NSError(ZeroKitError.badInput, message: "Tresor ID format error.")
        }
        
        iv = cipherData.subdata(in: index3 ..< index4)
        cipherBytes = cipherData.subdata(in: index4 ..< index5)
        adata = cipherData.subdata(in: cipherData.startIndex ..< index3) // format version, key version, tresor Id
    }
    
    func plainBytes(key: Data) -> Data? {
        return Crypto.aesGcmDecrypt(cipherData: cipherBytes, key: key, iv: iv, adata: adata, tagLength: 16)
    }
}

class PlainData {
    let plainBytes: Data
    private let randomProvider: RandomProvider
    
    init(data: Data, randomProvider: RandomProvider) {
        self.plainBytes = data
        self.randomProvider = randomProvider
    }
    
    func cipherBytes(tresorId: String, key: Data, keyVersion: UInt) throws -> Data? {
        let lebData = Leb128OutData()
        _ = encodeUnsignedLEB(lebData, value: 1) // format version
        _ = encodeUnsignedLEB(lebData, value: keyVersion)
        
        var adata = lebData.leb128Data
        adata.append(tresorId.data(using: .utf8)!)
        adata.append(0)
        
        let iv = try randomProvider.getRandom(bytes: 16)
        
        if let cipherBytes = Crypto.aesGcmEncrypt(plainData: plainBytes, key: key, iv: iv, adata: adata, tagLength: 16) {
            var cipherData = adata
            cipherData.append(iv)
            cipherData.append(cipherBytes)
            return cipherData
        }
        
        return nil
    }
}
