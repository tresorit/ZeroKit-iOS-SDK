import XCTest
import ZeroKit

class ZeroKitTestCaseBase: XCTestCase {
    
    let defaultTimeout: TimeInterval = 90
    var zeroKitStack: ZeroKitStack!
    
    override func setUp() {
        self.continueAfterFailure = false
        super.setUp()
        resetZeroKit()
    }
    
    override func tearDown() {
        zeroKitStack = nil
        super.tearDown()
    }
    
    func resetZeroKit() {
        self.zeroKitStack = createZeroKitStack()
    }
    
    func createZeroKitStack() -> ZeroKitStack {
        let configFile = Bundle.main.url(forResource: "Config", withExtension: "plist")!
        let configDict = NSDictionary(contentsOf: configFile)!
        
        let apiUrl = URL(string: configDict["ZeroKitAPIBaseURL"] as! String)!
        let clientId = configDict["ZeroKitClientId"] as! String
        let backendUrl = URL(string: configDict["ZeroKitAppBackend"] as! String)!
        
        let config = ZeroKitConfig(apiBaseUrl: apiUrl)
        let zeroKit = ZeroKit(config: config)
        
        let backend = Backend(withBackendBaseUrl: backendUrl, authorizationCallback: { credentialsCallback in
            zeroKit.getIdentityTokens(clientId: clientId) { tokens, error in
                credentialsCallback(tokens?.authorizationCode, clientId, error)
            }
        })
        
        return ZeroKitStack(zeroKit: zeroKit, backend: backend)
    }
    
    func registerUser(usingZeroKit: ZeroKitStack? = nil) -> TestUser {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        
        let username = "test-user-\(NSUUID().uuidString)"
        let profileData = "{ \"autoValidate\": true }" // User is automatically validated by the server
        
        var expectation = self.expectation(description: "Init registration")
        
        var userId: String!
        var regSessionId: String!
        
        zeroKitStack.backend.initRegistration(username: username, profileData: profileData) { aUserId, aRegSessionId, error in
            XCTAssertTrue(error == nil)
            userId = aUserId
            regSessionId = aRegSessionId
            print("Init reg: \(userId) \(regSessionId)")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        expectation = self.expectation(description: "Registration")
        
        var regValidationVerifier: String!
        let password = "Abc123"
        
        zeroKitStack.zeroKit.register(withUserId: userId, registrationId: regSessionId, password: password) { aRegValidationVerifier, error in
            guard error == nil else {
                XCTFail("Registration failed: \(error!)")
                return
            }
            
            regValidationVerifier = aRegValidationVerifier
            print("Registration: \(regValidationVerifier)")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        expectation = self.expectation(description: "Finish registration")
        
        zeroKitStack.backend.finishRegistration(userId: userId, validationVerifier: regValidationVerifier) { error in
            XCTAssertTrue(error == nil)
            print("Registration finished")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return TestUser(id: userId, username: username, password: password)
    }
    
    func loginUser(_ user: TestUser, usingZeroKit: ZeroKitStack? = nil, rememberMe: Bool = false, expectError: ZeroKitError? = nil) {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        let expectation = self.expectation(description: "Login")
        zeroKitStack.zeroKit.login(withUserId: user.id, password: user.password, rememberMe: rememberMe) { error in
            if let error = error {
                XCTAssertTrue(expectError != nil && error == expectError!, "Login failed with unexpected error: \(error)")
            } else {
                XCTAssertTrue(expectError == nil, "Login succeeded while expecting error: \(expectError!)");
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func loginByRememberMe(withUserId userId: String) {
        let expectation = self.expectation(description: "Login by remember me")
        
        zeroKitStack.zeroKit.loginByRememberMe(with: userId) { error in
            guard error == nil else {
                XCTFail("Failed to log in by remember me: \(error!)")
                return
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func logout(usingZeroKit: ZeroKitStack? = nil) {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        let expectation = self.expectation(description: "Logout")
        zeroKitStack.backend.forgetToken()
        zeroKitStack.zeroKit.logout { error in
            guard error == nil else {
                XCTFail("Logout failed: \(error!)")
                return
            }
            
            expectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func whoAmI(usingZeroKit: ZeroKitStack? = nil) -> String? {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        let expectation = self.expectation(description: "Who am I?")
        var userId: String?
        zeroKitStack.zeroKit.whoAmI { aUserId, error in
            userId = aUserId
            expectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        return userId
    }
    
    func createTresor(usingZeroKit: ZeroKitStack? = nil) -> String {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        
        var tresorId: String!
        
        let exptectTresorCreation = self.expectation(description: "Tresor creation")
        
        zeroKitStack.zeroKit.createTresor { aTresorId, error in
            guard error == nil else {
                XCTFail("Tresor creation failed: \(error!)")
                return
            }
            
            tresorId = aTresorId
            exptectTresorCreation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        let expectTresorApproval = self.expectation(description: "Tresor creation approval")
        
        zeroKitStack.backend.createdTresor(tresorId: tresorId) { error in
            XCTAssert(error == nil)
            expectTresorApproval.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return tresorId
    }
    
    func shareTresor(tresorId: String, withUser userId: String, usingZeroKit: ZeroKitStack? = nil) {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        let expectation = self.expectation(description: "Tresor sharing")
        
        zeroKitStack.zeroKit.share(tresorWithId: tresorId, withUser: userId) { shareId, error in
            guard error == nil else {
                XCTFail("Tresor sharing failed: \(error!)")
                return
            }
            
            zeroKitStack.backend.sharedTresor(operationId: shareId!) { error in
                XCTAssert(error == nil)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func kickUser(userId: String, fromTresor tresorId: String, usingZeroKit: ZeroKitStack? = nil) {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        let expectation = self.expectation(description: "Kicking user")
        
        zeroKitStack.zeroKit.kick(userWithId: userId, fromTresor: tresorId) { operationId, error in
            guard error == nil else {
                XCTFail("Kicking user failed: \(error!)")
                return
            }
            
            zeroKitStack.backend.kickedUser(operationId: operationId!) { error in
                XCTAssertTrue(error == nil)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func getInvitationLinkInfo(_ link: InvitationLink) -> InvitationLinkPublicInfo {
        var info: InvitationLinkPublicInfo?
        
        let expectation = self.expectation(description: "Getting link info")
        let secret = link.url.fragment!
        zeroKitStack.zeroKit.getInvitationLinkInfo(with: secret) { anInfo, error in
            guard error == nil else {
                XCTFail("Failed to get invitation link info: \(error!)")
                return
            }
            
            info = anInfo
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return info!
    }
    
    func changePassword(forUser user: TestUser, newPassword: String) -> TestUser {
        let expectation = self.expectation(description: "Changing password")
        
        zeroKitStack.zeroKit.changePassword(for: user.id, currentPassword: user.password, newPassword: newPassword) { error in
            guard error == nil else {
                XCTFail("Failed to change password: \(error!)")
                return
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return TestUser(id: user.id, username: user.username, password: newPassword)
    }
    
    func encrypt(plainText: String, inTresor tresorId: String, usingZeroKit: ZeroKitStack? = nil) -> String {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        let expectation = self.expectation(description: "Text encryption")
        
        var cipherText: String!
        zeroKitStack.zeroKit.encrypt(plainText: plainText, inTresor: tresorId) { aCipherText, error in
            guard error == nil else {
                XCTFail("Text encrpytion failed: \(error!)")
                return
            }
            
            cipherText = aCipherText
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return cipherText
    }
    
    func decrypt(cipherText: String, usingZeroKit: ZeroKitStack? = nil) -> String {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        let expectation = self.expectation(description: "Text decryption")
        
        var plainText: String!
        zeroKitStack.zeroKit.decrypt(cipherText: cipherText) { aPlainText, error in
            guard error == nil else {
                XCTFail("Text decryption failed: \(error!)")
                return
            }
            
            plainText = aPlainText
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return plainText
    }
    
    func encrypt(plainData: Data, inTresor tresorId: String, usingZeroKit: ZeroKitStack? = nil) -> Data {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        let expectation = self.expectation(description: "Data encryption")
        
        var cipherData: Data!
        zeroKitStack.zeroKit.encrypt(plainData: plainData, inTresor: tresorId) { aCipherData, error in
            guard error == nil else {
                XCTFail("Data encrpytion failed: \(error!)")
                return
            }
            
            cipherData = aCipherData
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return cipherData
    }
    
    func decrypt(cipherData: Data, usingZeroKit: ZeroKitStack? = nil) -> Data {
        let zeroKitStack = usingZeroKit ?? self.zeroKitStack!
        let expectation = self.expectation(description: "Data decryption")
        
        var plainData: Data!
        zeroKitStack.zeroKit.decrypt(cipherData: cipherData) { aPlainData, error in
            guard error == nil else {
                XCTFail("Data decryption failed: \(error!)")
                return
            }
            
            plainData = aPlainData
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return plainData
    }
}
