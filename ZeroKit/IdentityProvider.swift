import WebKit
import Security

public class ZeroKitIdentityTokens: NSObject {
    
    /**
     Authorization code.
     */
    public let authorizationCode: String
    
    /**
     Identity token.
     */
    public let identityToken: String
    
    /**
     Contains the code verifier if you have 'Requires proof key' enabled for your client.
     */
    public let codeVerifier: String?
    
    fileprivate init?(parameters: [String: String], codeVerifier: String?) {
        guard let authCode = parameters["code"],
            let idToken = parameters["id_token"] else {
            return nil
        }
        
        self.authorizationCode = authCode
        self.identityToken = idToken
        self.codeVerifier = codeVerifier
    }
}

/**
 ZeroKit identity provider (IdP) for OpenID Connect.
 */
class IdentityProvider: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let clientId: String
    private let config: ZeroKitConfig
    private let redirectUrl: String
    private var state: String?
    private var codeVerifier: String?
    private var completion: ZeroKit.IdentityTokensCompletion?
    
    deinit {
        self.webView.stopLoading()
        self.webView.removeFromSuperview()
    }
    
    init(clientId: String, config: ZeroKitConfig, processPool: WKProcessPool, webviewHostView: UIView) {
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.processPool = processPool
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: webViewConfig)
        self.clientId = clientId
        self.config = config
        self.redirectUrl = String(format: "%@://%@.%@/", config.apiBaseUrl.scheme!, clientId, config.apiBaseUrl.host!)
        
        super.init()
        
        self.webView.navigationDelegate = self
        webviewHostView.insertSubview(self.webView, at: 0)
    }
    
    func getIdentityTokens(useProofKey: Bool, completion: @escaping ZeroKit.IdentityTokensCompletion) {
        do {
            self.state = try IdentityProvider.generateCode()
            
            var params = [String: String]()
            params["client_id"] = self.clientId
            params["redirect_uri"] = self.redirectUrl
            params["response_type"] = "code id_token"
            params["scope"] = "openid profile"
            params["state"] = self.state
            params["nonce"] = try IdentityProvider.generateCode()
            params["response_mode"] = "fragment"
            params["prompt"] = "none"
            
            if useProofKey {
                self.codeVerifier = try IdentityProvider.generateCode()
                params["code_challenge"] = ZeroKitUrlSafeBase64Encode(ZeroKitSha256(self.codeVerifier!.data(using: .utf8)!)!)
                params["code_challenge_method"] = "S256"
            }
            
            let urlStr = String(format: "%@?%@",
                                config.idpAuthUrl.absoluteString,
                                String.zk_fromUrlParamDict(dictionary: params))
            
            self.completion = completion
            self.webView.load(URLRequest(url: URL(string: urlStr)!))
            
        } catch let error as NSError {
            completion(nil, error)
            return
        } catch {
            completion(nil, ZeroKitError.unknownError.nserrorValue)
            return
        }
    }
    
    func cancelRequest() {
        self.didFail(with: ZeroKitError.userInterrupted.nserrorValue)
        self.webView.stopLoading()
    }
    
    // MARK: Code challenge
    
    private class func generateCode() throws -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".characters
        var code = ""
        for _ in 0..<64 {
            let random = try Int(secureRandom32(max: UInt32(chars.count-1)))
            let index = chars.index(chars.startIndex, offsetBy: random)
            code.append(chars[index])
        }
        return code
    }
    
    private class func secureRandom32(max: UInt32) throws -> UInt32 {
        if max == UInt32.max {
            return try secureRandom32()
        }
        
        let maxp1 = max + 1
        var r: UInt32 = 0
        
        repeat {
            r = try secureRandom32()
        } while r <= (UInt32.max % maxp1)
        
        return r % maxp1
    }
    
    private class func secureRandom32() throws -> UInt32 {
        let randomBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
        if (SecRandomCopyBytes(kSecRandomDefault, 4, randomBytes) != errSecSuccess) {
            throw ZeroKitError.internalError.nserrorValue
        }
        return randomBytes.withMemoryRebound(to: UInt32.self, capacity: 4) {
            return $0.pointee
        }
    }
    
    // MARK: WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Check if error happened
        let errorHappened = "ErrorHappened"
        webView.evaluateJavaScript("if (document.querySelector('div.container').contains(document.querySelector('.lead.ng-binding')) && document.querySelector('div.alert.alert-danger').contains(document.querySelector('div.ng-binding'))) { \"\(errorHappened)\" } else { \"noError\" }") { [weak self] obj, error in
            
            if let result = obj as? String, result == errorHappened && error == nil {
                self?.didFail(with: ZeroKitError.unknownError.nserrorValue)
                self?.webView.stopLoading()
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.didFail(with: ZeroKitError.unknownError.nserrorValue)
        self.webView.stopLoading()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.absoluteString.lowercased().hasPrefix(self.redirectUrl.lowercased()) {
            didFinish(with: url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    
    // MARK: Finished
    
    private func didFinish(with redirectUrl: URL) {
        let parameters = redirectUrl.fragment?.zk_toUrlParamDict() ?? [String: String]()
        let state = parameters["state"]
        
        if state == nil || state! != self.state! {
            self.didFail(with: ZeroKitError.invalidResponse.nserrorValue)
            
        } else if let tokens = ZeroKitIdentityTokens(parameters: parameters, codeVerifier: self.codeVerifier) {
            self.didComplete(with: tokens)
            
        } else {
            let error = parameters["error"] ?? "unknown_error"
            let errorDesc = parameters["error_description"] ?? "unknown_error"
            
            switch error {
            case "invalid_request":
                if (errorDesc == "code challenge required") {
                    // Retry with proof key
                    self.getIdentityTokens(useProofKey: true, completion: self.completion!)
                } else {
                    self.didFail(with: ZeroKitError.invalidRequest.nserrorValue)
                }
                
            case "login_required":
                self.didFail(with: ZeroKitError.loginRequired.nserrorValue)
                
            default:
                self.didFail(with: ZeroKitError.unknownError.nserrorValue)
            }
        }
    }
    
    private func didComplete(with tokens: ZeroKitIdentityTokens) {
        if let completion = self.completion {
            self.completion = nil
            completion(tokens, nil)
        }
    }
    
    private func didFail(with error: NSError) {
        if let completion = self.completion {
            self.completion = nil
            completion(nil, error)
        }
    }
}

extension String {
    func zk_toUrlParamDict() -> [String: String] {
        let parameters = self.components(separatedBy: "&")
        
        var dict = [String: String]()
        for p in parameters {
            let keyValue = p.components(separatedBy: "=")
            if keyValue.count == 2 {
                dict[keyValue[0]] = keyValue[1].removingPercentEncoding
            }
        }
        
        return dict
    }
    
    static func zk_fromUrlParamDict(dictionary: [String: String]) -> String {
        let paramArray = dictionary.reduce([String]()) { (acc: [String], item: (key: String, value: String)) -> [String] in
            var macc = acc
            macc.append(String(format: "%@=%@", item.key, item.value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!))
            return macc
        }
        
        return paramArray.joined(separator: "&")
    }
}
