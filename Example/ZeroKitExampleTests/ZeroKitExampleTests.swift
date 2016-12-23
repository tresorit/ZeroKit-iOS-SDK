import XCTest
import ZeroKit

class ZeroKitExampleTests: XCTestCase {
    
    let defaultTimeout: TimeInterval = 90
    let mockApp = ExampleAppMock()
    let zeroKitApiUrl = URL(string: Bundle.main.infoDictionary!["ZeroKitAPIURL"] as! String)!
    var zeroKit: ZeroKit!
    
    override func setUp() {
        super.setUp()
        resetZeroKit()
    }
    
    override func tearDown() {
        zeroKit = nil
        super.tearDown()
    }
    
    func resetZeroKit() {
        let zeroKitConfig = ZeroKitConfig(apiUrl: zeroKitApiUrl)
        zeroKit = try! ZeroKit(config: zeroKitConfig)
        
        let expectation = self.expectation(description: "ZeroKit setup")
        
        let obsSucc = NotificationCenter.default.addObserver(forName: ZeroKit.DidLoadNotification, object: zeroKit, queue: nil) { notification in
            expectation.fulfill()
        }
        
        let obsFail = NotificationCenter.default.addObserver(forName: ZeroKit.DidFailLoadingNotification, object: zeroKit, queue: nil) { notification in
            XCTFail("Failed to load ZeroKit API")
        }
        
        defer {
            NotificationCenter.default.removeObserver(obsSucc)
            NotificationCenter.default.removeObserver(obsFail)
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func registerUser() -> TestUser {
        var expectation = self.expectation(description: "Init registration")
        
        var userId: String!
        var regSessionId: String!
        var regSessionVerifier: String!
        
        mockApp.initUserRegistration { (success, aUserId, aRegSessionId, aRegSessionVerifier) -> (Void) in
            XCTAssertTrue(success)
            userId = aUserId
            regSessionId = aRegSessionId
            regSessionVerifier = aRegSessionVerifier
            print("Init reg: \(userId) \(regSessionId) \(regSessionVerifier)")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        expectation = self.expectation(description: "Registration")
        
        var regValidationVerifier: String!
        let password = "Abc123"
        
        zeroKit.register(withUserId: userId, registrationId: regSessionId, password: password) { aRegValidationVerifier, error in
            guard error == nil else {
                XCTFail("Registration failed: \(error!)")
                return
            }
            
            regValidationVerifier = aRegValidationVerifier
            print("Registration: \(regValidationVerifier)")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        expectation = self.expectation(description: "User validation")
        
        mockApp.validateUser(userId, regSessionId: regSessionId, regSessionVerifier: regSessionVerifier, regValidationVerifier: regValidationVerifier) { (success) -> (Void) in
            XCTAssertTrue(success)
            print("Reg validation: \(success)")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return TestUser(id: userId, password: password)
    }
    
    func loginUser(_ user: TestUser, rememberMe: Bool = false, expectError: ZeroKitError? = nil) {
        let expectation = self.expectation(description: "Login")
        zeroKit.login(withUserId: user.id, password: user.password, rememberMe: rememberMe) { error in
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
        
        zeroKit.loginByRememberMe(with: userId) { error in
            guard error == nil else {
                XCTFail("Failed to log in by remember me: \(error!)")
                return
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func logout() {
        let expectation = self.expectation(description: "Logout")
        zeroKit.logout { error in
            guard error == nil else {
                XCTFail("Logout failed: \(error!)")
                return
            }
            
            expectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func whoAmI() -> String? {
        let expectation = self.expectation(description: "Who am I?")
        var userId: String?
        zeroKit.whoAmI { aUserId, error in
            userId = aUserId
            expectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        return userId
    }
    
    func createTresor() -> String {
        var tresorId: String!
        
        let expectation = self.expectation(description: "Tresor creation")
        
        zeroKit.createTresor { aTresorId, error in
            guard error == nil else {
                XCTFail("Tresor creation failed: \(error!)")
                return
            }
            
            self.mockApp.approveTresorCreation(aTresorId!, approve: true) { success in
                XCTAssertTrue(success)
                tresorId = aTresorId
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        return tresorId
    }
    
    func getInvitationLinkInfo(_ link: InvitationLink) -> InvitationLinkPublicInfo {
        var info: InvitationLinkPublicInfo?
        
        let expectation = self.expectation(description: "Getting link info")
        let secret = link.url.fragment!
        zeroKit.getInvitationLinkInfo(with: secret) { anInfo, error in
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
        
        zeroKit.changePassword(for: user.id, currentPassword: user.password, newPassword: newPassword) { error in
            guard error == nil else {
                XCTFail("Failed to change password: \(error!)")
                return
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return TestUser(id: user.id, password: newPassword)
    }
    
    // MARK: tests
    
    func testRegistration() {
        _ = registerUser()
    }
    
    func testLoginLogout() {
        let user = registerUser()
        loginUser(user)
        logout()
    }
    
    func testLoginWithNonexistentUser() {
        let user = TestUser(id: "NoSuchUser", password: "Password")
        loginUser(user, expectError: ZeroKitError.userDoesNotExist)
    }
    
    func testLoginWithInvalidPassword() {
        let user = registerUser()
        let invalidPwUser = TestUser(id: user.id, password: "Invalid password")
        loginUser(invalidPwUser, expectError: ZeroKitError.invalidAuthorization)
    }
    
    func testRememberMe() {
        let user = registerUser()
        loginUser(user, rememberMe: true)
        
        resetZeroKit()
        
        loginByRememberMe(withUserId: user.id)
        
        logout()
    }
    
    func testPasswordChange() {
        let user = registerUser()
        loginUser(user)
        
        let userNewPassword = changePassword(forUser: user, newPassword: "Xyz987")
        
        logout()
        
        loginUser(userNewPassword)
        logout()
    }
    
    func testPasswordChangeRememberMe() {
        let user = registerUser()
        loginUser(user, rememberMe: true)
        
        _ = changePassword(forUser: user, newPassword: "Xyz987")
        
        resetZeroKit()
        
        loginByRememberMe(withUserId: user.id)
        
        logout()
    }
    
    func testWhoAmI() {
        let userId1 = whoAmI()
        XCTAssertTrue(userId1 == nil)
        
        let user = registerUser()
        loginUser(user)
        
        let userId2 = whoAmI()
        XCTAssertTrue(userId2 != nil)
        XCTAssertTrue(userId2! == user.id)
        
        logout()
        
        let userId3 = whoAmI()
        XCTAssertTrue(userId3 == nil)
    }
    
    func testCreateTresor() {
        let user = registerUser()
        loginUser(user)
        let tresorId = createTresor()
        XCTAssertTrue(tresorId.characters.count > 0)
        logout()
    }
    
    func testTextEncryption() {
        let user = registerUser()
        loginUser(user)
        let tresorId = createTresor()
        
        var expectation = self.expectation(description: "Text encryption")
        
        let plainText = "This is the text to be encrypted"
        var cipherText: String!
        zeroKit.encrypt(plainText: plainText, inTresor: tresorId) { aCipherText, error in
            guard error == nil else {
                XCTFail("Text encrpytion failed: \(error!)")
                return
            }
            
            cipherText = aCipherText
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        expectation = self.expectation(description: "Text decryption")
        
        var plainText2: String!
        zeroKit.decrypt(cipherText: cipherText) { aPlainText, error in
            guard error == nil else {
                XCTFail("Text decryption failed: \(error!)")
                return
            }
            
            plainText2 = aPlainText
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        XCTAssertTrue(plainText == plainText2)
        
        logout()
    }
    
    func testDataEncryption() {
        let user = registerUser()
        loginUser(user)
        let tresorId = createTresor()
        
        var expectation = self.expectation(description: "Data encryption")
        
        let plainData = "This is the data to be encrypted".data(using: String.Encoding.utf8)!
        var cipherData: Data!
        zeroKit.encrypt(plainData: plainData, inTresor: tresorId) { aCipherData, error in
            guard error == nil else {
                XCTFail("Data encrpytion failed: \(error!)")
                return
            }
            
            cipherData = aCipherData
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        expectation = self.expectation(description: "Data decryption")
        
        var plainData2: Data!
        zeroKit.decrypt(cipherData: cipherData) { aPlainData, error in
            guard error == nil else {
                XCTFail("Data decryption failed: \(error!)")
                return
            }
            
            plainData2 = aPlainData
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        XCTAssertTrue(plainData == plainData2)
        
        logout()
    }
    
    func testTresorSharingAndKick() {
        let user1 = registerUser()
        let user2 = registerUser()
        
        loginUser(user1)
        let tresorId = createTresor()
        
        var expectation = self.expectation(description: "Tresor sharing")
        
        zeroKit.share(tresorWithId: tresorId, withUser: user2.id) { shareId, error in
            guard error == nil else {
                XCTFail("Tresor sharing failed: \(error!)")
                return
            }
            
            self.mockApp.approveShare(shareId!, approve: true) { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        expectation = self.expectation(description: "Kicking user")
        
        zeroKit.kick(userWithId: user2.id, fromTresor: tresorId) { operationId, error in
            guard error == nil else {
                XCTFail("Kicking user failed: \(error!)")
                return
            }
            
            self.mockApp.approveKick(operationId!, approve: true) { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testInvitationLinkNoPassword() {
        let user1 = registerUser()
        let user2 = registerUser()
        
        loginUser(user1)
        let tresorId = createTresor()
        
        let baseUrlStr = "https://tresorit.io/"
        let message = "This is the message"
        
        var expectation = self.expectation(description: "Creating link without password")
        
        var link: InvitationLink?
        
        zeroKit.createInvitationLinkWithoutPassword(with: URL(string: baseUrlStr)!, forTresor: tresorId, withMessage: message) { aLink, error in
            guard error == nil else {
                XCTFail("Failed to create invitation link without password: \(error!)")
                return
            }
            
            self.mockApp.approveCreateInvitationLink(aLink!.id, approve: true) { success in
                XCTAssertTrue(success)
                link = aLink
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        logout()
        
        loginUser(user2)
        
        let info = getInvitationLinkInfo(link!)
        print("Link info: \(info)")
        
        XCTAssertTrue(info.creatorUserId == user1.id)
        XCTAssertTrue(info.message! == message)
        XCTAssertFalse(info.isPasswordProtected)
        
        expectation = self.expectation(description: "Accepting link without password")
        
        zeroKit.acceptInvitationLinkWithoutPassword(with: info.token) { operationId, error in
            guard error == nil else {
                XCTFail("Failed to accept invitation link without password: \(error!)")
                return
            }
            
            self.mockApp.approveAcceptInvitationLink(operationId!, approve: true) { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testInvitationLink() {
        let user1 = registerUser()
        let user2 = registerUser()
        
        loginUser(user1)
        let tresorId = createTresor()
        
        let baseUrlStr = "https://tresorit.io/"
        let message = "This is the message"
        let password = "Password1."
        
        var expectation = self.expectation(description: "Creating link with password")
        
        var link: InvitationLink?
        
        zeroKit.createInvitationLink(with: URL(string: baseUrlStr)!, forTresor: tresorId, withMessage: message, password: password) { aLink, error in
            guard error == nil else {
                XCTFail("Failed to create invitation link with password: \(error!)")
                return
            }
            
            self.mockApp.approveCreateInvitationLink(aLink!.id, approve: true) { success in
                XCTAssertTrue(success)
                link = aLink
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        logout()
        
        loginUser(user2)
        
        let info = getInvitationLinkInfo(link!)
        print("Link info: \(info)")
        
        XCTAssertTrue(info.creatorUserId == user1.id)
        XCTAssertTrue(info.message! == message)
        XCTAssertTrue(info.isPasswordProtected)
        
        expectation = self.expectation(description: "Accepting link with password")
        
        zeroKit.acceptInvitationLink(with: info.token, password: password) { operationId, error in
            guard error == nil else {
                XCTFail("Failed to accept invitation link with password: \(error!)")
                return
            }
            
            self.mockApp.approveAcceptInvitationLink(operationId!, approve: true) { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
}
