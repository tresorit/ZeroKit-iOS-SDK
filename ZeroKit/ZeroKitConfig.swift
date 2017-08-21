import Foundation

/**
 Configuration for ZeroKit.
 
 Keychain configuration properties affect the storage of the "remember me" token.
 */
public class ZeroKitConfig: NSObject, NSCopying {
    let serviceUrl: URL
    let apiJs: [ApiJs]
    let idpAuthUrl: URL
    
    let isTesting: Bool
    let isFormatTesting: Bool
    
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
     The maximum number of queries submitted to ZeroKit that are executed concurrently.
     
     The default value is `1`.
     */
    public var concurrentQueryLimit = 1
    
    /**
     Initialize a configuration with your service URL. The URL is your tenant's URL.
     
     - parameter serviceUrl: Your service URL. You can find it on the ZeroKit management portal, https://manage.tresorit.io/.
     */
    public convenience init(serviceUrl: URL) {
        self.init(serviceUrl: serviceUrl, isTesting: false, isFormatTesting: false)
    }
    
    init(serviceUrl: URL, isTesting: Bool, isFormatTesting: Bool) {
        self.serviceUrl = serviceUrl
        self.isTesting = isTesting
        self.isFormatTesting = isFormatTesting
        
        let apiVersion = "v5"
        let bundle = Bundle(for: ZeroKitConfig.classForCoder())
        
        self.apiJs = [
            ApiJsUrl(sourceUrl: serviceUrl.appendingPathComponent("static/\(apiVersion)/jsCorePrelude.js")),
            ApiJsUrl(sourceUrl: bundle.url(forResource: "ZeroKitInit", withExtension: "js")!),
            ApiJsUrl(sourceUrl: bundle.url(forResource: "ZeroKitInitFormat", withExtension: "js")!, shouldLoad: isFormatTesting),
            ApiJsUrl(sourceUrl: serviceUrl.appendingPathComponent("static/\(apiVersion)/worker-session-es6.js")),
            ApiJsUrl(sourceUrl: serviceUrl.appendingPathComponent("static/\(apiVersion)/jsCoreWrapper.js")),
            ApiJsUrl(sourceUrl: serviceUrl.appendingPathComponent("static/js/zxcvbn.js")),
            ApiJsUrl(sourceUrl: bundle.url(forResource: "ZeroKit", withExtension: "js")!),
            ApiJsUrl(sourceUrl: bundle.url(forResource: "jsCoreFormatWrapper", withExtension: "js")!, shouldLoad: isTesting),
        ]
        
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
        let copy = ZeroKitConfig(serviceUrl: self.serviceUrl, isTesting: self.isTesting, isFormatTesting: self.isFormatTesting)
        copy.keychainAccessGroup = self.keychainAccessGroup
        copy.keychainAccessibility = self.keychainAccessibility
        return copy
    }
}
