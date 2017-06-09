import XCTest
@testable import ZeroKit

class ZeroKitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testLogLevel() {
        ZeroKit.logLevel = .off
        
        XCTAssertFalse(Log.shouldLog(.off))
        XCTAssertFalse(Log.shouldLog(.error))
        XCTAssertFalse(Log.shouldLog(.warning))
        XCTAssertFalse(Log.shouldLog(.info))
        XCTAssertFalse(Log.shouldLog(.debug))
        XCTAssertFalse(Log.shouldLog(.verbose))
        
        ZeroKit.logLevel = .error
        
        XCTAssertFalse(Log.shouldLog(.off))
        XCTAssertTrue(Log.shouldLog(.error))
        XCTAssertFalse(Log.shouldLog(.warning))
        XCTAssertFalse(Log.shouldLog(.info))
        XCTAssertFalse(Log.shouldLog(.debug))
        XCTAssertFalse(Log.shouldLog(.verbose))
        
        ZeroKit.logLevel = .warning
        
        XCTAssertFalse(Log.shouldLog(.off))
        XCTAssertTrue(Log.shouldLog(.error))
        XCTAssertTrue(Log.shouldLog(.warning))
        XCTAssertFalse(Log.shouldLog(.info))
        XCTAssertFalse(Log.shouldLog(.debug))
        XCTAssertFalse(Log.shouldLog(.verbose))
        
        ZeroKit.logLevel = .info
        
        XCTAssertFalse(Log.shouldLog(.off))
        XCTAssertTrue(Log.shouldLog(.error))
        XCTAssertTrue(Log.shouldLog(.warning))
        XCTAssertTrue(Log.shouldLog(.info))
        XCTAssertFalse(Log.shouldLog(.debug))
        XCTAssertFalse(Log.shouldLog(.verbose))
        
        ZeroKit.logLevel = .debug
        
        XCTAssertFalse(Log.shouldLog(.off))
        XCTAssertTrue(Log.shouldLog(.error))
        XCTAssertTrue(Log.shouldLog(.warning))
        XCTAssertTrue(Log.shouldLog(.info))
        XCTAssertTrue(Log.shouldLog(.debug))
        XCTAssertFalse(Log.shouldLog(.verbose))
        
        ZeroKit.logLevel = .verbose
        
        XCTAssertFalse(Log.shouldLog(.off))
        XCTAssertTrue(Log.shouldLog(.error))
        XCTAssertTrue(Log.shouldLog(.warning))
        XCTAssertTrue(Log.shouldLog(.info))
        XCTAssertTrue(Log.shouldLog(.debug))
        XCTAssertTrue(Log.shouldLog(.verbose))
    }
    
    func testSha256() {
        let result = Crypto().sha256("63696361")
        XCTAssertNotNil(result)
        print(result!)
        XCTAssertTrue(result!.isEqual(to: "93cc4ad2a2102405c97fd2128f4e9e0cd704273373a11f7443a91850f7a57ce7"))
    }
    
    func testSha512() {
        let result = Crypto().sha512("63696361")
        XCTAssertNotNil(result)
        print(result!)
        XCTAssertTrue(result!.isEqual(to: "c8469bc870aa603214fe6ca003458dc70ce2e598f6363198840d1bbdd1cfd4af60d48704d7092b3b3960c13f72a2d468f3a524b25e98e10c6cb878fed9a870ce"))
    }
    
    func testPbkdf2HmacSha256() {
        let size = 32
        let result = Crypto().pbkdf2HmacSha256("63696361", "00010203", 100000, size)
        XCTAssertNotNil(result)
        print(result!)
        XCTAssertTrue(result!.length == size * 2)
        XCTAssertTrue(result!.isEqual(to: "27e901d8f60a5893e496c1d3613fe05655e47f421fc34d8e046586249d5d0bd9"))
    }
    
    func testPbkdf2HmacSha512() {
        let size = 32
        let result = Crypto().pbkdf2HmacSha512("63696361", "00010203", 100000, size)
        XCTAssertNotNil(result)
        print(result!)
        XCTAssertTrue(result!.length == size * 2)
        XCTAssertTrue(result!.isEqual(to: "b4bb3435c292ec7cb60477190e0fd459d4c2b550ace22664b0256e09a1d0e78f"))
    }
    
    func testHmacSha256() {
        let result = Crypto().hmacSha256("63696361", "00010203")
        XCTAssertNotNil(result)
        print(result!)
        XCTAssertTrue(result!.isEqual(to: "3cea206f6daa60f5cd3d6bde07ae9494ddfdf95c5f579a50c0bde6a4ac9c24bf"))
    }
    
    func testAes128Gcm() {
        let plainTextOriginal: NSString = "636963616369636163696361636963616369636163696361"
        let key: NSString = "93cc4ad2a2102405c97fd2128f4e9e0c"
        let iv: NSString = "b9abdd7e4f97f9cd3c43c72f0d45e10e"
        let aad: NSString = "00010203"
        let tagLength = 16
        
        let cipherText = Crypto().aesGcmEncrypt(plainTextOriginal, key, iv, aad, tagLength)
        XCTAssertNotNil(cipherText)
        print(cipherText!)
        // CipherText + Tag
        XCTAssertTrue(cipherText!.isEqual(to: "bd341d4a643f7ccf35815d0e50756a8db6ba65e0e6a7991daa0d304cf49c54d6fbd1dc4b0e56745f"))
        
        let plaintText = Crypto().aesGcmDecrypt(cipherText!, key, iv, aad, tagLength)
        XCTAssertNotNil(plaintText)
        print(plaintText!)
        XCTAssertTrue(plaintText!.isEqual(to: plainTextOriginal as String))
    }
    
    func testAes256Gcm() {
        let plainTextOriginal: NSString = "636963616369636163696361636963616369636163696361"
        let key: NSString = "93cc4ad2a2102405c97fd2128f4e9e0cd704273373a11f7443a91850f7a57ce7"
        let iv: NSString = "b9abdd7e4f97f9cd3c43c72f0d45e10e"
        let aad: NSString = "00010203"
        let tagLength = 16
        
        let cipherText = Crypto().aesGcmEncrypt(plainTextOriginal, key, iv, aad, tagLength)
        XCTAssertNotNil(cipherText)
        print(cipherText!)
        // CipherText + Tag
        XCTAssertTrue(cipherText!.isEqual(to: "1649250498fcd9c58ff957939a3ff9c1b4fe7e0dd1d88514d2a4be8ff4179febcf137e7a73d62473"))
        
        let plaintText = Crypto().aesGcmDecrypt(cipherText!, key, iv, aad, tagLength)
        XCTAssertNotNil(plaintText)
        print(plaintText!)
        XCTAssertTrue(plaintText!.isEqual(to: plainTextOriginal as String))
    }
}
