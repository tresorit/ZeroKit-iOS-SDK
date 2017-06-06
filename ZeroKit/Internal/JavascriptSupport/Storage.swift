import JavaScriptCore

@objc protocol StorageJSExport: JSExport {
    func getItem(_ key: String) -> Any
    func setItem(_ key: String, _ value: String)
    func removeItem(_ key: String)
}

@objc protocol PersistenceKeysJSExport: JSExport {
    func getWebSessionKey() -> Any
    func setWebSessionKey(_ value: String)
    func removeWebSessionKey()
    
    func getWebRememberKey() -> Any
    func setWebRememberKey(_ value: String)
    func removeWebRememberKey()
}

class MapStorage: NSObject, StorageJSExport {
    private var map: [String: String]!
    
    override convenience init() {
        self.init(map: nil)
    }
    
    init(map: [String: String]?) {
        self.map = map ?? [:]
    }
    
    func allItems() -> [String: String] {
        var retVal: [String: String]!
        zk_synchronized {
            retVal = self.map
        }
        return retVal
    }
    
    // MARK: StorageJSExport
    
    func getItem(_ key: String) -> Any {
        var retVal: Any!
        zk_synchronized {
            retVal = self.map[key] ?? NSNull()
        }
        return retVal
    }
    
    func setItem(_ key: String, _ value: String) {
        zk_synchronized {
            self.map[key] = value
        }
    }
    
    func removeItem(_ key: String) {
        zk_synchronized {
            self.map.removeValue(forKey: key)
        }
    }
}

class PersistenceKeys: MapStorage, PersistenceKeysJSExport {
    private let SessionKey = "SessionKey"
    private let RememberKey = "RememberKey"
    
    init() {
        super.init(map: [:])
    }
    
    func getWebSessionKey() -> Any {
        return self.getItem(SessionKey)
    }
    
    func setWebSessionKey(_ value: String) {
        self.setItem(SessionKey, value)
    }
    
    func removeWebSessionKey() {
        self.removeItem(SessionKey)
    }
    
    func getWebRememberKey() -> Any {
        return self.getItem(RememberKey)
    }
    
    func setWebRememberKey(_ value: String) {
        self.setItem(RememberKey, value)
    }
    
    func removeWebRememberKey() {
        self.removeItem(RememberKey)
    }
    
    func cookies(for domain: String) -> [String] {
        var c = [String]()
        if let webSessionKey = getWebSessionKey() as? String {
            c.append(String(format: "wsk=%@;domain=%@;path=/;secure", webSessionKey, domain))
        }
        if let webRememberKey = getWebRememberKey() as? String {
            c.append(String(format: "wrk=%@;domain=%@;path=/;secure", webRememberKey, domain))
        }
        return c
    }
}
