import UIKit

/** This is a mock database that should be served by your application's backend. This example mobile app has its own database so it can be run without the need of setting up a backend. */
class ExampleAppMockDatabase: NSObject {
    fileprivate let defaults = UserDefaults.standard
    
    fileprivate var usernameUserIdMap: [String: String] {
        get {
            let map = UserDefaults.standard.object(forKey: "usernameUserIdMap")
            return (map as? [String: String]) ?? [String: String]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "usernameUserIdMap")
        }
    }
    
    func userIdForUsername(_ username: String) -> String? {
        return usernameUserIdMap[username]
    }
    
    func usernameForUserId(_ userId: String) -> String? {
        for (savedUsername, savedUserId) in usernameUserIdMap {
            if savedUserId == userId {
                return savedUsername
            }
        }
        return nil
    }
    
    func saveUserId(_ userId: String, forUsername username: String) {
        var map = usernameUserIdMap
        map[username] = userId
        usernameUserIdMap = map
    }
    
    fileprivate var userIdTresorIdsMap: [String: [String]] {
        get {
            let map = UserDefaults.standard.object(forKey: "userIdTresorIdsMap")
            return (map as? [String: [String]]) ?? [String: [String]]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "userIdTresorIdsMap")
        }
    }
    
    func tresorsForUser(_ userId: String) -> [String]? {
        return userIdTresorIdsMap[userId]
    }
    
    func addTresor(_ tresorId: String, forUser userId: String) {
        var map = userIdTresorIdsMap
        var tresors: [String] = map[userId] ?? [String]()
        tresors.append(tresorId)
        map[userId] = tresors
        userIdTresorIdsMap = map
    }
}
