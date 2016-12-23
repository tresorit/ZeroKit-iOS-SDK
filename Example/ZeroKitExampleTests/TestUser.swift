import Foundation

class TestUser: NSObject {
    let id: String
    let password: String
    
    init(id: String, password: String) {
        self.id = id
        self.password = password
    }
}
