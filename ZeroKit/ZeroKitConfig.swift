import UIKit

/**
 Configuration for ZeroKit.
 
 Keychain configuration properties affect the storage of the "remember me" token.
 */
public class ZeroKitConfig: NSObject, NSCopying {
    let serviceUrl: URL
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
     
     - parameter serviceUrl: Your service URL. You can find it on the ZeroKit management portal, https://manage.tresorit.io/.
     */
    public init(serviceUrl: URL) {
        self.serviceUrl = serviceUrl
        self.apiUrl = serviceUrl.appendingPathComponent("static/v5/api.html")
        self.idpAuthUrl = serviceUrl.appendingPathComponent("idp/connect/authorize")
        self.keychainAccessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }
    
    /**
     Initialize a configuration with your service URL (API base URL).
     
     - parameter apiBaseUrl: Your service URL. You can find it on the ZeroKit management portal.
     */
    @available(*, deprecated: 5.0.0, message: "Use init(serviceUrl: URL) instead. This method has been renamed for consistency.")
    public convenience init(apiBaseUrl: URL) {
        self.init(serviceUrl: apiBaseUrl)
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = ZeroKitConfig(serviceUrl: self.serviceUrl)
        copy.keychainAccessGroup = self.keychainAccessGroup
        copy.keychainAccessibility = self.keychainAccessibility
        return copy
    }
}
