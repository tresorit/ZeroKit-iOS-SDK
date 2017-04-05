import Foundation

public class TestUser: NSObject {
    public let id: String
    public let username: String
    public let password: String
    
    public init(id: String, username: String, password: String) {
        self.id = id
        self.username = username
        self.password = password
    }
}
