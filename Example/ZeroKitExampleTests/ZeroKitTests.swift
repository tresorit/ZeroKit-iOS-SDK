import XCTest
import ZeroKit

class ZeroKitTests: ZeroKitTestCaseBase {
    func testRegistration() {
        _ = registerUser()
    }
    
    func testLoginLogout() {
        let user = registerUser()
        loginUser(user)
        logout()
    }
    
    func testLoginWithInvalidUser() {
        let user = TestUser(id: "InvalidUserID", username: "DoesNotMatter", password: "Password")
        loginUser(user, expectError: ZeroKitError.invalidUserId)
    }
    
    func testLoginWithInvalidPassword() {
        let user = registerUser()
        let invalidPwUser = TestUser(id: user.id, username: user.username, password: "Invalid password")
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
        
        let plainText = "This is the text to be encrypted"
        let cipherText = encrypt(plainText: plainText, inTresor: tresorId)
        let plainText2 = decrypt(cipherText: cipherText)
        
        XCTAssertTrue(plainText == plainText2)
        
        logout()
    }
    
    func testDataEncryption() {
        let user = registerUser()
        loginUser(user)
        let tresorId = createTresor()
        
        let plainData = "This is the data to be encrypted".data(using: String.Encoding.utf8)!
        let cipherData = encrypt(plainData: plainData, inTresor: tresorId)
        let plainData2 = decrypt(cipherData: cipherData)
        
        XCTAssertTrue(plainData == plainData2)
        
        logout()
    }
    
    func testTresorSharingAndKick() {
        let user1 = registerUser()
        let user2 = registerUser()
        
        loginUser(user1)
        let tresorId = createTresor()
        
        shareTresor(tresorId: tresorId, withUser: user2.id)
        kickUser(userId: user2.id, fromTresor: tresorId)
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
        
        zeroKitStack.zeroKit.createInvitationLinkWithoutPassword(with: URL(string: baseUrlStr)!, forTresor: tresorId, withMessage: message) { aLink, error in
            guard error == nil else {
                XCTFail("Failed to create invitation link without password: \(error!)")
                return
            }
            
            self.zeroKitStack.backend.createdInvitationLink(operationId: aLink!.id) { error in
                XCTAssertTrue(error == nil)
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
        
        zeroKitStack.zeroKit.acceptInvitationLinkWithoutPassword(with: info.token) { operationId, error in
            guard error == nil else {
                XCTFail("Failed to accept invitation link without password: \(error!)")
                return
            }
            
            self.zeroKitStack.backend.acceptedInvitationLink(operationId: operationId!) { error in
                XCTAssertTrue(error == nil)
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
        
        zeroKitStack.zeroKit.createInvitationLink(with: URL(string: baseUrlStr)!, forTresor: tresorId, withMessage: message, password: password) { aLink, error in
            guard error == nil else {
                XCTFail("Failed to create invitation link with password: \(error!)")
                return
            }
            
            self.zeroKitStack.backend.createdInvitationLink(operationId: aLink!.id) { error in
                XCTAssertTrue(error == nil)
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
        
        zeroKitStack.zeroKit.acceptInvitationLink(with: info.token, password: password) { operationId, error in
            guard error == nil else {
                XCTFail("Failed to accept invitation link with password: \(error!)")
                return
            }
            
            self.zeroKitStack.backend.acceptedInvitationLink(operationId: operationId!) { error in
                XCTAssertTrue(error == nil)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testTwoSimultaneousUsers() {
        let zeroKitStack1 = createZeroKitStack()
        let zeroKitStack2 = createZeroKitStack()
        
        let user1 = registerUser()
        let user2 = registerUser()
        
        loginUser(user1, usingZeroKit: zeroKitStack1)
        loginUser(user2, usingZeroKit: zeroKitStack2)
        
        XCTAssertTrue(whoAmI(usingZeroKit: zeroKitStack1)! == user1.id)
        XCTAssertTrue(whoAmI(usingZeroKit: zeroKitStack2)! == user2.id)
        
        let tresorId = createTresor(usingZeroKit: zeroKitStack1)
        
        let plainText = "Plain text"
        
        // encrypt with user1
        let cipherText = encrypt(plainText: plainText, inTresor: tresorId, usingZeroKit: zeroKitStack1)
        
        shareTresor(tresorId: tresorId, withUser: user2.id, usingZeroKit: zeroKitStack1)
        
        // decrypt with user2
        let plainText2 = decrypt(cipherText: cipherText, usingZeroKit: zeroKitStack2)
        
        XCTAssertTrue(plainText == plainText2)
        
        logout(usingZeroKit: zeroKitStack1)
        logout(usingZeroKit: zeroKitStack2)
    }
}
