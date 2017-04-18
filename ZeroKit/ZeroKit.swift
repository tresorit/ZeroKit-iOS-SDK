import WebKit

/**
 The ZeroKit class provides the interface to the ZeroKit SDK on iOS.
 
 - note: The ZeroKit API is not thread safe, call only from the main thread.
 */
public class ZeroKit: NSObject {
    
    fileprivate let config: ZeroKitConfig
    fileprivate var internalApi: InternalApi!
    fileprivate var idpQuery: IdentityProvider?
    fileprivate var nextIdpCalls = [(/*isCancelled: */Bool) -> Void]()
    
    /**
     Initialize ZeroKit with the configuration.
     
     - parameter config: config for ZeroKit
     - throws: ZeroKitError.cannotAddWebView
     */
    public init(config: ZeroKitConfig) throws {
        self.config = config.copy() as! ZeroKitConfig
        super.init()
        self.internalApi = InternalApi(apiUrl: config.apiUrl, webViewHostView: try ZeroKit.hostViewForWebView(), zeroKit: self)
    }

    fileprivate class func hostViewForWebView() throws -> UIView {
        guard let windowOptional = UIApplication.shared.delegate?.window, let window = windowOptional else {
            throw ZeroKitError.cannotAddWebView.nserrorValue
        }
        return window
    }
}

fileprivate extension ZeroKit {
    static let serviceName = "com.zerokit.rememberme"
    
    func save(rememberMeKey: String, forUserId userId: String) -> Bool {
        _ = deleteRememberMeKey(forUserId: userId)
        
        let attr = NSMutableDictionary()
        attr[kSecClass] = kSecClassGenericPassword
        attr[kSecAttrService] = ZeroKit.serviceName
        attr[kSecAttrAccount] = userId
        attr[kSecValueData] = rememberMeKey.data(using: .utf8)
        attr[kSecAttrAccessible] = self.config.keychainAccessibility
        
        if let group = self.config.keychainAccessGroup {
            attr[kSecAttrAccessGroup] = group
        }
        
        let status = SecItemAdd(attr, nil)
        return status == errSecSuccess
    }
    
    func deleteRememberMeKey(forUserId userId: String) -> Bool {
        let attr = NSMutableDictionary()
        attr[kSecClass] = kSecClassGenericPassword
        attr[kSecAttrService] = ZeroKit.serviceName
        attr[kSecAttrAccount] = userId
        let status = SecItemDelete(attr)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    func rememberMeKey(forUserId userId: String) -> String? {
        let query = NSMutableDictionary()
        query[kSecClass] = kSecClassGenericPassword
        query[kSecAttrService] = ZeroKit.serviceName
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecAttrAccount] = userId

        var result: CFTypeRef? = nil
        let status = SecItemCopyMatching(query, &result)
        
        if status != errSecSuccess || result == nil {
            return nil
        }
        
        let data = result as! Data
        let key = String(data: data, encoding: .utf8)
        
        return key
    }
}

/**
 Invitation links can be used to give access to tresors. Use the ZeroKit class to create invitation links.
 */
public class InvitationLink: NSObject {
    public let id: String
    public let url: URL
    
    fileprivate init?(result: AnyObject) {
        guard let dict = result as? NSDictionary,
            let linkId = dict["id"] as? String,
            let urlStr = dict["url"] as? String,
            let url = URL(string: urlStr) else {
                return nil
        }
        
        self.id = linkId
        self.url = url
    }
}

/**
 Contains information about an invitation link. You can get the information by calling `getInvitationLinkInfo`.
 */
public class InvitationLinkPublicInfo: NSObject {
    public let token: String
    public let isPasswordProtected: Bool
    public let creatorUserId: String
    public let message: String?
    
    fileprivate init?(result: AnyObject) {
        guard let dict = result as? NSDictionary,
            let tokenId = dict["tokenId"],
            let creatorUserId = dict["creatorUserId"] as? String else {
                return nil
        }
        
        self.token = "\(tokenId)"
        if let isPasswordProtected = dict["isPasswordProtected"] {
            self.isPasswordProtected = ("\(isPasswordProtected)" as NSString).boolValue
        } else {
            self.isPasswordProtected = false
        }
        self.creatorUserId = creatorUserId
        self.message = dict["message"] as? String
    }
}

public extension ZeroKit {
    
    // MARK: API methods
    
    public typealias DefaultCompletion = (NSError?) -> Void
    public typealias RegistrationCompletion = (/* validation verifier */ String?, NSError?) -> Void
    public typealias UserIdCompletion = (/* user ID */ String?, NSError?) -> Void
    public typealias TresorIdCompletion = (/* tresor ID */ String?, NSError?) -> Void
    public typealias CipherTextCompletion = (/* cipher text */ String?, NSError?) -> Void
    public typealias PlainTextCompletion = (/* plain text */ String?, NSError?) -> Void
    public typealias CipherDataCompletion = (/* cipher data */ Data?, NSError?) -> Void
    public typealias PlainDataCompletion = (/* plain data */ Data?, NSError?) -> Void
    public typealias InvitationLinkCompletion = (InvitationLink?, NSError?) -> Void
    public typealias InvitationLinkInfoCompletion = (InvitationLinkPublicInfo?, NSError?) -> Void
    public typealias OperationIdCompletion = (/* operation ID */ String?, NSError?) -> Void
    public typealias PasswordStrengthCallback = (PasswordStrength?, NSError?) -> Void
    public typealias IdentityTokensCompletion = (ZeroKitIdentityTokens?, NSError?) -> Void
    
    /**
     Estimate the strength of a password.
     
     - parameter passwordField: The password field containing the password typed by the user.
     - parameter completion: Called when the strength calculation completes.
     */
    public func passwordStrength(passwordField: ZeroKitPasswordField, completion: @escaping PasswordStrengthCallback) {
        passwordStrength(password: passwordField.password, completion: completion)
    }
    
    /**
     Prefer using `passwordStrength(passwordField: ZeroKitPasswordField, userData: [String]? = nil, completion: @escaping PasswordStrengthCallback)` to avoid handling the user's password.
     
     - parameter password: The password.
     - parameter completion: Called when the strength calculation completes.
     */
    public func passwordStrength(password: String, completion: @escaping PasswordStrengthCallback) {
        let pwParam = InternalApi.escapeParameter(password)
        internalApi.runJavascript("zxcvbn(\"\(pwParam)\")") { result, error in
            DispatchQueue.main.async {
                if let dict = result as? [String: Any], let strength = PasswordStrength(strengthDictionary: dict) {
                    completion(strength, nil)
                } else {
                    completion(nil, ZeroKitError.from(result).nserrorValue)
                }
            }
        }
    }
    
    /**
     Register a user. This is the second step of the 3-step registration flow. Before this method is called a user registration session must be initialized through the administration API of the ZeroKit backend. For more information on the registration flow please refer to the ZeroKit documentation.
     
     - parameter userId: User ID received when initialized registration session
     - parameter registrationId: Registration session ID received when initialized registration session
     - parameter passwordField: Password field containing the password typed by the user
     - parameter completion: Called when registration finishes
     */
    public func register(withUserId userId: String, registrationId: String, passwordField: ZeroKitPasswordField, completion: @escaping RegistrationCompletion) {
        register(withUserId: userId, registrationId: registrationId, password: passwordField.password, completion: completion)
    }
    
    /**
     Prefer using `register(withUserId userId: String, registrationId: String, passwordField: ZeroKitPasswordField, completion: @escaping RegistrationCompletion)` to avoid handling the user's password.
     
     - parameter userId: User ID received when initialized registration session
     - parameter registrationId: Registration session ID received when initialized registration session
     - parameter password: Password chosen by the user
     - parameter completion: Called when registration finishes
     */
    public func register(withUserId userId: String, registrationId: String, password: String, completion: @escaping RegistrationCompletion) {
        guard !password.isEmpty else {
            completion(nil, ZeroKitError.passwordIsEmpty.nserrorValue)
            return
        }
        
        self.internalApi.callMethod("mobileCmd.register", parameters: [userId, registrationId, password]) { success, result in
            if let dict = result as? NSDictionary, let regValidationVerifier = dict["RegValidationVerifier"] as? String , success {
                completion(regValidationVerifier, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Login using the ZeroKit backend.
     
     - parameter userId: User ID
     - parameter passwordField: Password field containing the password typed by the user
     - parameter rememberMe: Set to true if you want to log in the user without password by calling `loginWithRememberMe`
     - parameter completion: Called when login finishes
     */
    public func login(withUserId userId: String, passwordField: ZeroKitPasswordField, rememberMe: Bool, completion: @escaping DefaultCompletion) {
        login(withUserId: userId, password: passwordField.password, rememberMe: rememberMe, completion: completion)
    }
    
    /**
     Prefer using `login(with userId: String, passwordField: ZeroKitPasswordField, rememberMe: Bool, completion: @escaping UserIdCallback)` to avoid handling the user's password.
     
     - parameter userId: User ID
     - parameter password: User password
     - parameter rememberMe: Set to true if you want to log in the user without password by calling `loginWithRememberMe`
     - parameter completion: Called when login finishes
     */
    public func login(withUserId userId: String, password: String, rememberMe: Bool, completion: @escaping DefaultCompletion) {
        if rememberMe {
            getRememberMeKey(withUserId: userId, password: password) { rememberMeKey, error in
                guard let rememberMeKey = rememberMeKey, error == nil else {
                    completion(error)
                    return
                }
                
                self.loginByRememberMe(with: userId, rememberMeKey: rememberMeKey, completion: completion)
            }
            
        } else {
            self.internalApi.callMethod("mobileCmd.login", parameters: [userId, password]) { success, result in
                if success {
                    completion(nil)
                } else {
                    completion(ZeroKitError.from(result).nserrorValue)
                }
            }
        }
    }
    
    /**
     Use this method for login if 'remember me' was set to yes for a previous login with password.
     
     - parameter userId: The user ID to log in with
     - parameter completion: Called when login finishes
     */
    public func loginByRememberMe(with userId: String, completion: @escaping DefaultCompletion) {
        guard let rememberMeKey = rememberMeKey(forUserId: userId) else {
            completion(ZeroKitError.cannotLoginByRememberMe.nserrorValue)
            return
        }
        
        self.loginByRememberMe(with: userId, rememberMeKey: rememberMeKey, completion: completion)
    }
    
    private func loginByRememberMe(with userId: String, rememberMeKey: String, completion: @escaping DefaultCompletion) {
        self.internalApi.callMethod("mobileCmd.loginByRememberMeKey", parameters: [userId, rememberMeKey]) { success, result in
            if let userId = result as? String , success {
                _ = self.save(rememberMeKey: rememberMeKey, forUserId: userId)
                completion(nil)
            } else {
                completion(ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    private func getRememberMeKey(withUserId userId: String, password: String, completion: @escaping (String?, NSError?) -> Void) {
        self.internalApi.callMethod("mobileCmd.getRememberMeKey", parameters: [userId, password]) { success, result in
            if let rememberMeKey = result as? String, success {
                completion(rememberMeKey, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Check if the user can be logged in with the `loginWithRememberMe` method.
     
     - parameter userId: User ID
     - returns: `true` if the user can be logged in, `false` otherwise
     */
    public func canLoginByRememberMe(with userId: String) -> Bool {
        return rememberMeKey(forUserId: userId) != nil
    }
    
    /**
     Logout. If the user logged in with 'remember me' option, then they will have to re-enter their password to access any data.
     
     - parameter completion: Called when logout finishes
     */
    public func logout(completion: @escaping DefaultCompletion) {
        cancelAllIdpRequests()
        
        whoAmI { userId, error in
            guard error == nil else {
                completion(error)
                return
            }
            
            if let userId = userId {
                _ = self.deleteRememberMeKey(forUserId: userId)
            }
            
            self.internalApi.callMethod("cmd.api.logout", parameters: []) { success, result in
                completion(success ? nil : ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Change password.
     
     - parameter userId: The user ID of the current user
     - parameter currentPasswordField: The password field containing the user's current password
     - parameter newPasswordField: The password field containing the user's new password
     */
    public func changePassword(for userId: String, currentPasswordField: ZeroKitPasswordField, newPasswordField: ZeroKitPasswordField, completion: @escaping DefaultCompletion) {
        changePassword(for: userId, currentPassword: currentPasswordField.password, newPassword: newPasswordField.password, completion: completion)
    }
    
    /**
     Prefer using `changePassword(for userId: String, currentPasswordField: ZeroKitPasswordField, newPasswordField: ZeroKitPasswordField, completion: @escaping DefaultCompletion)` to avoid handling the user's password.
     
     - parameter userId: The user ID of the current user
     - parameter currentPassword: The current password
     - parameter newPassword: The new password
     */
    public func changePassword(for userId: String, currentPassword: String, newPassword: String, completion: @escaping DefaultCompletion) {
        guard !newPassword.isEmpty else {
            completion(ZeroKitError.passwordIsEmpty.nserrorValue)
            return
        }
        
        self.internalApi.callMethod("mobileCmd.changePassword", parameters: [userId, currentPassword, newPassword]) { success, result in
            if success {
                
                if self.canLoginByRememberMe(with: userId) {
                    // Also update the remember me key
                    self.getRememberMeKey(withUserId: userId, password: newPassword) { rememberMeKey, error in
                        if let rememberMeKey = rememberMeKey, error == nil {
                            _ = self.save(rememberMeKey: rememberMeKey, forUserId: userId)
                        }
                        
                        completion(nil)
                    }
                    
                } else {
                    completion(nil)
                }
                
            } else {
                completion(ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Use this methods to get the logged in user's identity.
     
     - parameter completion: Called when `whoAmI` finishes. Returns the user ID if logged in or `nil` if not.
     */
    public func whoAmI(completion: @escaping UserIdCompletion) {
        self.internalApi.callMethod("cmd.api.whoAmI", parameters: []) { success, result in
            if success {
                let userId = result as? String
                completion(userId, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Encrypts the plain text by the given tresor.
     
     - parameter plainText: The plain text to encrypt
     - parameter tresorId: The id of the tresor, that will be used to encrypt the text
     - parameter completion: Called when encryption finishes, contains the cipher text if successful
     */
    public func encrypt(plainText: String, inTresor tresorId: String, completion: @escaping CipherTextCompletion) {
        self.internalApi.callMethod("cmd.api.encrypt", parameters: [tresorId, plainText]) { success, result in
            if let cipherText = result as? String , success {
                completion(cipherText, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Decrypts the given cipherText.
     
     - note: You do not need to provide a tresor ID to decrypt the cipher text. If the user has access to the tresor that was used for encryption then decryption will succeed.
     
     - parameter cipherText: ZeroKit encrypted text
     - parameter completion: Called when decryption finishes, contains the plain text if successful
     */
    public func decrypt(cipherText: String, completion: @escaping PlainTextCompletion) {
        self.internalApi.callMethod("cmd.api.decrypt", parameters: [cipherText]) { success, result in
            if let plainText = result as? String , success {
                completion(plainText, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Encrypts the plain bytes by the given tresor.
     
     - parameter plainData: The plain data to encrypt
     - parameter tresorId: The id of the tresor, that will be used to encrypt the text
     - parameter completion: Called when encryption finishes, contains the cipher data if successful
     */
    public func encrypt(plainData: Data, inTresor tresorId: String, completion: @escaping CipherDataCompletion) {
        let plainDataBase64 = plainData.base64EncodedString()
        
        let params = [InternalApi.MethodParameter(plainValue: tresorId),
                      InternalApi.MethodParameter(escapedValue: plainDataBase64)]
        
        self.internalApi.callMethod("ios_cmd_api_encryptBytes", methodParameters: params) { success, result in
            if let cipherDataBase64 = result as? String,
                let cipherData = Data(base64Encoded: cipherDataBase64),
                success {
                completion(cipherData, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Decrypts the given cipher bytes.
     
     - parameter cipherData: ZeroKit encrypted data
     - parameter completion: Called when decryption finishes, contains the plain data if successful
     */
    public func decrypt(cipherData: Data, completion: @escaping PlainDataCompletion) {
        let cipherDataBase64 = cipherData.base64EncodedString()
        
        let params = [InternalApi.MethodParameter(escapedValue: cipherDataBase64)]
        
        self.internalApi.callMethod("ios_cmd_api_decryptBytes", methodParameters: params) { success, result in
            if let plainDataBase64 = result as? String,
                let plainData = Data(base64Encoded: plainDataBase64),
                success {
                completion(plainData, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Creates a tresor bound to the user but it will only be usable once it's approved. The tresor ID returned in the completion callback should be saved as it is the only way to identifiy the tresor.

     - parameter completion: Called when tresor creation finishes, contains the tresor ID if successful. Approve this tresor through the administration API of the ZeroKit backend.
     */
    public func createTresor(completion: @escaping TresorIdCompletion) {
        self.internalApi.callMethod("cmd.api.createTresor", parameters: []) { success, result in
            if let tresorId = result as? String, success {
                completion(tresorId, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Shares the tresor with the given user. The operation will only be effective after it is approved using the returned OperationId. This uploads a modified tresor, but the new version is downloadable only after it has been approved. This should be done as soon as possible, as approving any operation to a tresor may invalidate any pending ones
     
     - parameter tresorId: ID of the tresor to be shared
     - parameter userId: ID of the user to share the tresor with
     - parameter completion: Called when the operation finishes, contains the operationId required to approve the operation.
     */
    public func share(tresorWithId tresorId: String, withUser userId: String, completion: @escaping OperationIdCompletion) {
        self.internalApi.callMethod("cmd.api.shareTresor", parameters: [tresorId, userId]) { success, result in
            if let opId = result as? String, success {
                completion(opId, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Removes the given user from the tresor. The operation will only be effective after it is approved using the returned OperationId.
     
     - parameter userId: ID of the user to kick
     - parameter tresorId: ID of the tresor to kick from
     - parameter completion: Called when the operation finishes, contains the operationId required to approve the operation.
     */
    public func kick(userWithId userId: String, fromTresor tresorId: String, completion: @escaping OperationIdCompletion) {
        self.internalApi.callMethod("cmd.api.kickFromTresor", parameters: [tresorId, userId]) { success, result in
            if let opId = result as? String, success {
                completion(opId, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     This method will add the user to the tresor of the link using the entered password.
     
     - parameter token: The `token` field of the `InvitationLinkPublicInfo` of the link returned by `getInvitationLinkInfo`.
     - parameter passwordField: The password field containing the required password to accept the invitation link.
     - parameter completion: Called when the operation finishes, contains the operationId required to approve the operation.
     */
    public func acceptInvitationLink(with token: String, passwordField: ZeroKitPasswordField, completion: @escaping OperationIdCompletion) {
        acceptInvitationLink(with: token, password: passwordField.password, completion: completion)
    }
    
    /**
     Prefer using `acceptInvitationLink(with token: String, passwordField: ZeroKitPasswordField, completion: @escaping OperationIdCompletion)` to avoid handling the password.
     
     - parameter token: The `token` field of the `InvitationLinkPublicInfo` of the link returned by `getInvitationLinkInfo`.
     - parameter password: The password required to accept the invitation link.
     - parameter completion: Called when the operation finishes, contains the operationId required to approve the operation.
     */
    public func acceptInvitationLink(with token: String, password: String, completion: @escaping OperationIdCompletion) {
        self.internalApi.callMethod("ios_mobileCmd_acceptInvitationLink", parameters: [token, password]) { success, result in
            if let opId = result as? String, success {
                completion(opId, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     This method will add the user to the tresor of the link.
     
     - parameter token: The `token` field of the `InvitationLinkPublicInfo` of the link returned by `getInvitationLinkInfo`.
     - parameter completion: Called when the operation finishes, contains the operationId required to approve the operation.
     */
    public func acceptInvitationLinkWithoutPassword(with token: String, completion: @escaping OperationIdCompletion) {
        self.internalApi.callMethod("ios_cmd_api_acceptInvitationLinkNoPassword", parameters: [token]) { success, result in
            if let opId = result as? String, success {
                completion(opId, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Creates an invitation link that can be used by the invitee to gain access to the tresor. The secret that can be used to open the invitation link is concatenated to the end of the link after a '#'. It is done so, because this way the secret never travels to your (or our servers). We recommend that you use password protected links and to transfer these passwords on a different channel than the link. This operation needs administrative approval.
     
     - parameter linkBase: the base of the link. The link secret is concatenated after this after a '#'
     - parameter tresorId: the id of the tresor
     - parameter message: optional arbitrary string data that can be retrieved without a password or any other information
     - parameter passwordField: password field containing the password required to accept the invitation link
     - parameter completion: contains the created link if successful
     */
    public func createInvitationLink(with linkBase: URL, forTresor tresorId: String, withMessage message: String, passwordField: ZeroKitPasswordField, completion: @escaping InvitationLinkCompletion) {
        createInvitationLink(with: linkBase, forTresor: tresorId, withMessage: message, password: passwordField.password, completion: completion)
    }
    
    /**
     Prefer using `createInvitationLink(with linkBase: URL, forTresor tresorId: String, withMessage message: String, passwordField: ZeroKitPasswordField, completion: @escaping InvitationLinkCompletion)` to avoid handling the password.
     
     - parameter linkBase: the base of the link. The link secret is concatenated after this after a '#'
     - parameter tresorId: the id of the tresor
     - parameter message: optional arbitrary string data that can be retrieved without a password or any other information
     - parameter password: password required to accept the invitation link
     - parameter completion: contains the created link if successful
     */
    public func createInvitationLink(with linkBase: URL, forTresor tresorId: String, withMessage message: String, password: String, completion: @escaping InvitationLinkCompletion) {
        self.internalApi.callMethod("mobileCmd.createInvitationLink", parameters: [linkBase.absoluteString, tresorId, message, password]) { success, result in
            if let link = InvitationLink(result: result), success {
                completion(link, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Creates an invitation link that can be used by the invitee to gain access to the tresor. The secret that can be used to open the invitation link is concatenated to the end of the link after a '#'. It is done so, because this way the secret never travels to your (or our servers). We recommend that you use password protected links and to transfer these passwords on a different channel than the link. This operation needs administrative approval.
     
     - parameter linkBase: the base of the link. The link secret is concatenated after this after a '#'
     - parameter tresorId: the id of the tresor
     - parameter message: optional arbitrary string data that can be retrieved without a password or any other information
     - parameter completion: contains the created link if successful
     */
    public func createInvitationLinkWithoutPassword(with linkBase: URL, forTresor tresorId: String, withMessage message: String, completion: @escaping InvitationLinkCompletion) {
        self.internalApi.callMethod("cmd.api.createInvitationLinkNoPassword", parameters: [linkBase.absoluteString, tresorId, message]) { success, result in
            if let link = InvitationLink(result: result), success {
                completion(link, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Retrieves information about the link.
     
     - parameter secret: The secret is in the fragment identifier of the link url
     - parameter completion: Return information about the link when finishes.
     */
    public func getInvitationLinkInfo(with secret: String, completion: @escaping InvitationLinkInfoCompletion) {
        self.internalApi.callMethod("ios_cmd_api_getInvitationLinkInfo", parameters: [secret]) { success, result in
            if let linkInfo = InvitationLinkPublicInfo(result: result) , success {
                completion(linkInfo, nil)
            } else {
                completion(nil, ZeroKitError.from(result).nserrorValue)
            }
        }
    }
    
    /**
     Get authorization code and identity tokens for the currenty logged in user.
     
     You can set up Open ID clients on the ZeroKit management portal. The client used with the mobile SDK should have the following settings:
     
     - Redirect URL should have the following format: 'https://{Client ID}.{Tenant ID}.api.tresorit.io/'
     - Flow should be set to 'Hybrid'
     - You can optionally turn on 'Requires proof key (DHCE)'
     
     **User must be logged in when calling this method.**
     
     - parameter clientId: The cliend ID for the current ZeroKit OpenID Connect client set up in the management portal.
     - parameter completion: Returns the identity tokens or an error if an error occurred.
     */
    public func getIdentityTokens(clientId: String, completion: @escaping IdentityTokensCompletion) {
        if self.idpQuery == nil {
            self.getIdentityTokensInner(clientId: clientId, useProofKey: false, completion: completion)
        } else {
            self.nextIdpCalls.append({ [weak self] (isCancelled) in
                if isCancelled {
                    completion(nil, ZeroKitError.userInterrupted.nserrorValue)
                } else {
                    self?.getIdentityTokensInner(clientId: clientId, useProofKey: false, completion: completion)
                }
            })
        }
    }
    
    private func getIdentityTokensInner(clientId: String, useProofKey: Bool, completion: @escaping IdentityTokensCompletion) {
        var webViewHostView: UIView?
        do {
            webViewHostView = try ZeroKit.hostViewForWebView()
        } catch {
            completion(nil, error as NSError)
            runNextIdpRequest()
            return
        }
        
        self.idpQuery = IdentityProvider(clientId: clientId,
                                         config: self.config,
                                         processPool: self.internalApi.processPool,
                                         webviewHostView: webViewHostView!)
        
        self.idpQuery!.getIdentityTokens(useProofKey: useProofKey) { [weak self] (identityTokens, error) in
            completion(identityTokens, error)
            self?.idpQuery = nil
            self?.runNextIdpRequest()
        }
    }
    
    private func runNextIdpRequest() {
        if self.nextIdpCalls.count > 0 {
            let next = self.nextIdpCalls.removeFirst()
            next(false)
        }
    }
    
    private func cancelAllIdpRequests() {
        while self.nextIdpCalls.count > 0 {
            let next = self.nextIdpCalls.removeFirst()
            next(true)
        }
        self.idpQuery?.cancelRequest()
    }
}

// MARK: deprecated

public extension ZeroKit {
    
    /**
     `true` if the SDK was successfully loaded, `false` otherwise.
     */
    @available(*, deprecated: 4.1.0, message: "You no longer need to wait for ZeroKit API to load, you can make calls instantly. API will be loaded in the background and retried if needed.")
    public var isLoaded: Bool {
        get { return self.internalApi.isLoaded }
    }
    
    // MARK: Notifications
    
    /**
     `DidLoadNotification` notification is posted when the SDK is successfully loaded. `ZeroKit.isLoaded` is also set to `true`.
     */
    @available(*, deprecated: 4.1.0, message: "You no longer need to wait for ZeroKit API to load, you can make calls instantly. API will be loaded in the background and retried if needed.")
    public static let DidLoadNotification = DidLoadNotificationInner
    internal static let DidLoadNotificationInner = Notification.Name("ZeroKit.DidLoadNotification")
    
    /**
     `DidFailLoadingNotification` notification is posted when loading the SDK fails. `ZeroKit.isLoaded` is `false` if it fails.
     */
    @available(*, deprecated: 4.1.0, message: "You no longer need to wait for ZeroKit API to load, you can make calls instantly. API will be loaded in the background and retried if needed.")
    public static let DidFailLoadingNotification = DidFailLoadingNotificationInner
    internal static let DidFailLoadingNotificationInner = Notification.Name("ZeroKit.DidFailLoadingNotification")
    
}
