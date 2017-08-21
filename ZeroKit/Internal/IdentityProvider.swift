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
    private let internalApi: InternalApi
    private let randomProvider: RandomProvider
    
    private let clientId: String
    private let redirectUrl: String
    private var state: String?
    private var codeVerifier: String?
    
    private var isCancelled = false
    private var isServiceUrlPageLoaded = false
    
    private var useProofKey = false
    private var completion: ZeroKit.IdentityTokensCompletion?
    
    deinit {
        let wv = self.webView
        DispatchQueue.main.async {
            // Call webview only from main thread
            wv.stopLoading()
            wv.removeFromSuperview()
        }
    }
    
    init(clientId: String, internalApi: InternalApi, webviewHostView: UIView, randomProvider: RandomProvider) {
        
        let scriptJsUrl = Bundle(for: IdentityProvider.classForCoder()).url(forResource: "IDP", withExtension: "js")!
        let scriptJs = try! String(contentsOf: scriptJsUrl)
        let script = WKUserScript(source: scriptJs, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        
        let controller = WKUserContentController()
        controller.addUserScript(script)
        
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.userContentController = controller;

        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: webViewConfig)
        self.clientId = clientId
        
        let serviceUrl = internalApi.config.serviceUrl
        self.redirectUrl = String(format: "%@://%@.%@/", serviceUrl.scheme!, clientId, serviceUrl.host!)
        self.internalApi = internalApi
        self.randomProvider = randomProvider
        
        super.init()
        
        self.webView.navigationDelegate = self
        webviewHostView.insertSubview(self.webView, at: 0)
    }
    
    func getIdentityTokens(useProofKey: Bool, completion: @escaping ZeroKit.IdentityTokensCompletion) {
        self.completion = completion
        self.useProofKey = useProofKey
        
        // Load page for service URL. Only after that can we set the cookies.
        webView.loadHTMLString("", baseURL: internalApi.config.serviceUrl)
    }
    
    private func setCookiesAndData() {
        let parameters: [Any] = [
            internalApi.persistenceKeys.cookies(for: internalApi.config.serviceUrl.host!),
            internalApi.localStorage.allItems().map { [$0, $1] },
            internalApi.sessionStorage.allItems().map { [$0, $1] }
        ]
        
        let jsonParameters = try! JSONSerialization.data(withJSONObject: parameters, options: [])
        let jsonStringParameters = String(data: jsonParameters, encoding: .utf8)!

        let js = String(format: "ios_setCookiesAndData(%@)", jsonStringParameters)
        webView.evaluateJavaScript(js) { _, error in
            if error != nil {
                self.completion?(nil, NSError(error))
            } else {
                self.sendIdentityTokensRequest()
            }
        }
    }
    
    private func sendIdentityTokensRequest() {
        if self.isCancelled {
            return
        }
        
        do {
            self.state = try generateCode()
            
            var params = [String: String]()
            params["client_id"] = self.clientId
            params["redirect_uri"] = self.redirectUrl
            params["response_type"] = "code id_token"
            params["scope"] = "openid profile"
            params["state"] = self.state
            params["nonce"] = try generateCode()
            params["response_mode"] = "fragment"
            params["prompt"] = "none"
            
            if useProofKey {
                self.codeVerifier = try generateCode()
                params["code_challenge"] = ZeroKitUrlSafeBase64Encode(ZeroKitSha256(self.codeVerifier!.data(using: .utf8)!)!)
                params["code_challenge_method"] = "S256"
            }
            
            let urlStr = String(format: "%@?%@",
                                internalApi.config.idpAuthUrl.absoluteString,
                                String.zk_fromUrlParamDict(dictionary: params))
            
            self.webView.load(URLRequest(url: URL(string: urlStr)!))
            
        } catch {
            self.completion?(nil, NSError(error))
            return
        }
    }
    
    func cancelRequest() {
        self.isCancelled = true
        self.didFail(with: NSError(ZeroKitError.userInterrupted))
        self.webView.stopLoading()
    }
    
    // MARK: Code challenge
    
    private func generateCode() throws -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".characters
        var code = ""
        for _ in 0..<64 {
            let random = try self.randomProvider.randomUInt32(max: UInt32(chars.count-1))
            let index = chars.index(chars.startIndex, offsetBy: Int(random))
            code.append(chars[index])
        }
        return code
    }
    
    // MARK: WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !isServiceUrlPageLoaded {
            isServiceUrlPageLoaded = true
            setCookiesAndData()
            return
        }
        
        // Check if error happened
        let errorHappened = "ErrorHappened"
        webView.evaluateJavaScript("if (document.querySelector('div.container').contains(document.querySelector('.lead.ng-binding')) && document.querySelector('div.alert.alert-danger').contains(document.querySelector('div.ng-binding'))) { \"\(errorHappened)\" } else { \"noError\" }") { [weak self] obj, error in
            
            if let result = obj as? String, result == errorHappened && error == nil {
                self?.didFail(with: NSError(nil))
                self?.webView.stopLoading()
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.didFail(with: NSError(error))
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
            self.didFail(with: NSError(ZeroKitError.invalidResponse))
            
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
                    self.didFail(with: NSError(ZeroKitError.invalidRequest))
                }
                
            case "login_required":
                self.didFail(with: NSError(ZeroKitError.loginRequired))
                
            default:
                self.didFail(with: NSError(error))
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
            macc.append(String(format: "%@=%@", item.key, item.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!))
            return macc
        }
        
        return paramArray.joined(separator: "&")
    }
}
