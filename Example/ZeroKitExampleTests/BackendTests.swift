import XCTest
import ZeroKit

class BackendTests: ZeroKitTestCaseBase {
    
    typealias ProfileJson = [String: Any]
    
    func setProfile(json: ProfileJson) {
        let data = try! JSONSerialization.data(withJSONObject: json, options: [])
        let profile = String(data: data, encoding: .utf8)!
        
        let expectation = self.expectation(description: "Set profile")
        
        zeroKitStack.backend.setProfile(data: profile) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func getProfileAsJson() -> ProfileJson? {
        var profile: String?
        let expectation = self.expectation(description: "Get profile")
        
        zeroKitStack.backend.getProfile { aProfile, error in
            XCTAssertNil(error)
            profile = aProfile
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        if let profile = profile {
            let json = try! JSONSerialization.jsonObject(with: profile.data(using: .utf8)!, options: [.allowFragments])
            return (json as! ProfileJson)
        }
        
        return nil
    }
    
    func setPublicProfile(json: ProfileJson) {
        let data = try! JSONSerialization.data(withJSONObject: json, options: [])
        let profile = String(data: data, encoding: .utf8)!
        
        let expectation = self.expectation(description: "Set public profile")
        
        zeroKitStack.backend.storePublicProfile(data: profile) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func getPublicProfileAsJson(for userId: String) -> ProfileJson? {
        var profile: String?
        let expectation = self.expectation(description: "Get public profile")
        
        zeroKitStack.backend.getPublicProfile(for: userId) { aProfile, error in
            XCTAssertNil(error)
            profile = aProfile
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        if let profile = profile {
            let json = try! JSONSerialization.jsonObject(with: profile.data(using: .utf8)!, options: [.allowFragments])
            return (json as! ProfileJson)
        }
        
        return nil
    }
    
    func store(data: String, withId: String, inTresor: String) {
        let expectation = self.expectation(description: "Store data")
        
        zeroKitStack.backend.store(data: data, withId: withId, inTresor: inTresor) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func getData(withId: String) -> String? {
        var retVal: String?
        let expectation = self.expectation(description: "Get data")
        
        zeroKitStack.backend.getData(withId: withId) { str, error in
            XCTAssertNil(error)
            retVal = str
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        return retVal
    }
    
    // MARK: Tests
    
    func testProfileData() {
        let user = registerUser()
        loginUser(user)
        
        let dict: ProfileJson = ["a number": 42,
                                 "a string": "what's next?",
                                 "and a bool": true]
        
        setProfile(json: dict)
        let dict2 = getProfileAsJson()
        
        XCTAssertNotNil(dict2)
        XCTAssertTrue(NSDictionary(dictionary: dict).isEqual(to: dict2!))
    }
    
    func testPublicProfile() {
        let user = registerUser()
        loginUser(user)
        
        let defaultProfile = getPublicProfileAsJson(for: user.id)
        XCTAssertNil(defaultProfile)
        
        let dict: ProfileJson = ["public": "profile",
                                 "id": user.id]
        
        setPublicProfile(json: dict)
        let dict2 = getPublicProfileAsJson(for: user.id)
        
        XCTAssertNotNil(dict2)
        XCTAssertTrue(NSDictionary(dictionary: dict).isEqual(to: dict2!))
        
        logout()
        
        // Fetch profile with other user
        let user2 = registerUser()
        loginUser(user2)
        
        let dict3 = getPublicProfileAsJson(for: user.id)
        
        XCTAssertNotNil(dict3)
        XCTAssertTrue(NSDictionary(dictionary: dict).isEqual(to: dict3!))
    }
    
    func testDataStore() {
        let user = registerUser()
        loginUser(user)
        
        let tresor = createTresor()
        let plainText = "Plain text"
        let cipherText = encrypt(plainText: plainText, inTresor: tresor)
        
        let key = UUID().uuidString
        store(data: cipherText, withId: key, inTresor: tresor)
        
        let fetchedText = getData(withId: key)!
        let plainText2 = decrypt(cipherText: fetchedText)
        
        XCTAssertTrue(plainText == plainText2)
    }
    
    func testGetUserId() {
        let user = registerUser()
        
        let expectation = self.expectation(description: "Get user ID")
        var userId: String?
        
        zeroKitStack.backend.getUserId(forUsername: user.username) { aUserId, error in
            XCTAssertNil(error)
            XCTAssertNotNil(aUserId)
            userId = aUserId
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        
        XCTAssertTrue(user.id == userId!)
    }
}
