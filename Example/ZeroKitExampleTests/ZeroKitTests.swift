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
    
    func testMultiTresorCreation() {
        let user = registerUser()
        loginUser(user)
        
        var j = 0
        for i in 0 ..< 100 {
            let expectation = self.expectation(description: "Create tresor \(i)")
            
            zeroKitStack.zeroKit.createTresor { tresorId, error in
                defer {
                    j += 1
                    expectation.fulfill()
                }
                guard error == nil else {
                    XCTFail("[\(j)] Tresor creation \(i) failed: \(error!).")
                    return
                }
                print("[\(j)] Tresor \(i) \(tresorId!) created.")
            }
        }
        
        waitForExpectations(timeout: 5*60, handler: nil)
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
        invitationLinkTester(creator: { (linkBaseUrl, tresorId, message, _, completion) in
            zeroKitStack.zeroKit.createInvitationLinkWithoutPassword(with: linkBaseUrl, forTresor: tresorId, withMessage: message, completion: completion)
            
        }, accepter: { (token, _, completion) in
            zeroKitStack.zeroKit.acceptInvitationLinkWithoutPassword(with: token, completion: completion)
        })
    }
    
    func testInvitationLink() {
        invitationLinkTester(creator: { (linkBaseUrl, tresorId, message, password, completion) in
            zeroKitStack.zeroKit.createInvitationLink(with: linkBaseUrl, forTresor: tresorId, withMessage: message, password: password, completion: completion)
            
        }, accepter: { (token, password, completion) in
            zeroKitStack.zeroKit.acceptInvitationLink(with: token, password: password, completion: completion)
        })
    }
    
    func invitationLinkTester(creator: (URL, String, String, String, @escaping ZeroKit.InvitationLinkCompletion) -> Void,
                              accepter: (String, String, @escaping ZeroKit.OperationIdCompletion) -> Void) {
        let user1 = registerUser()
        let user2 = registerUser()
        
        loginUser(user1)
        let tresorId = createTresor()
        
        // Create link
        
        let baseUrlStr = "https://tresorit.io/"
        let message = "This is the message"
        let password = "Password1."
        
        var link: InvitationLink?
        var expectation = self.expectation(description: "Creating link")
        
        creator(URL(string: baseUrlStr)!, tresorId, message, password) { aLink, error in
            guard error == nil else {
                XCTFail("Failed to create invitation link: \(error!)")
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
        
        // Accept link
        
        expectation = self.expectation(description: "Accepting link")
        
        accepter(info.token, password) { operationId, error in
            guard error == nil else {
                XCTFail("Failed to accept invitation link: \(error!)")
                return
            }
            
            self.zeroKitStack.backend.acceptedInvitationLink(operationId: operationId!) { error in
                XCTAssertTrue(error == nil)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        logout()
        
        loginUser(user1)
        
        // Revoke link
        
        expectation = self.expectation(description: "Revoking link")
        
        let secret = link!.url.fragment!
        zeroKitStack.zeroKit.revokeInvitationLink(forTresor: tresorId, secret: secret) { operationId, error in
            guard error == nil else {
                XCTFail("Failed to revoke invitation link: \(error!)")
                return
            }
            
            self.zeroKitStack.backend.revokedInvitationLink(operationId: operationId!) { error in
                XCTAssertTrue(error == nil)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        logout()
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
