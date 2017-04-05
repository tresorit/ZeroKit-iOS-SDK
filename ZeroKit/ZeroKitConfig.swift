import UIKit

/**
 Configuration for ZeroKit.
 
 Keychain configuration properties affect the storage of the "remember me" token.
 */
public class ZeroKitConfig: NSObject, NSCopying {
    let apiBaseUrl: URL
    let apiUrl: URL
    let idpAuthUrl: URL
    
    /**
     Specify the keychain access group if your app needs one.
     */
    public var keychainAccessGroup: String?
    
    /**
     Keychain accessibility option. The default value is `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
     
     See Apple's documentation for Keychain Item Accessibility Constants that describes the possible values for the `kSecAttrAccessible` key.
     */
    public var keychainAccessibility: CFString
    
    /**
     Initialize a configuration with your service URL. The URL is your tenant's URL.
     
     - parameter apiBaseUrl: Your service URL. You can find it on the ZeroKit management portal.
     */
    public init(apiBaseUrl: URL) {
        self.apiBaseUrl = apiBaseUrl
        self.apiUrl = apiBaseUrl.appendingPathComponent("static/v4/api.html")
        self.idpAuthUrl = apiBaseUrl.appendingPathComponent("idp/connect/authorize")
        self.keychainAccessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }
    
    /**
     Initialize a configuration with the API URL.
     
     - parameter apiUrl: URL for the API
     */
    @available(*, deprecated: 4.1.0, message: "Use init(apiBaseUrl: URL) instead")
    public convenience init(apiUrl: URL) {
        let apiBaseUrl = apiUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        self.init(apiBaseUrl: apiBaseUrl)
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = ZeroKitConfig(apiBaseUrl: self.apiBaseUrl)
        copy.keychainAccessGroup = self.keychainAccessGroup
        copy.keychainAccessibility = self.keychainAccessibility
        return copy
    }
}
