import WebKit

class InternalApi: NSObject {
    
    typealias JsApiResultCallback = (/*success:*/ Bool, /*result:*/ AnyObject) -> Void
    typealias ErrorCallback = (Error?) -> Void
    
    struct MethodParameter {
        let value: String
        
        init(plainValue: String) {
            self.value = InternalApi.escapeParameter(plainValue)
        }
        
        init(escapedValue: String) {
            self.value = escapedValue
        }
    }
    
    private enum ApiState {
        case notLoaded
        case loading
        case didLoad
    }
    
    private let apiUrl: URL
    private var apiState = ApiState.notLoaded
    private var webView: WKWebView!
    private var webViewDelegate: WebViewDelegate!
    private var callbacks = [String: JsApiResultCallback]()
    private var apiLoadCompletions = [ErrorCallback]()
    private weak var zeroKit: ZeroKit?
    
    let processPool = WKProcessPool()
    var isLoaded: Bool {
        get { return self.apiState == .didLoad }
    }
    
    deinit {
        self.webView?.stopLoading()
        self.webView?.removeFromSuperview()
    }
    
    init(apiUrl: URL, webViewHostView: UIView, zeroKit: ZeroKit) {
        self.apiUrl = apiUrl
        self.zeroKit = zeroKit
        super.init()
        createWebView(hostView: webViewHostView)
        loadApi { _ in }
    }
    
    private func createWebView(hostView: UIView) {
        self.webViewDelegate = WebViewDelegate(internalApi: self)
        
        let controller = WKUserContentController()
        let messageHandlerName = "ZeroKitHandler" // referenced in javascript
        controller.add(self.webViewDelegate, name: messageHandlerName)
        
        let scriptJsUrl = Bundle(for: self.classForCoder).url(forResource: "ZeroKit", withExtension: "js")!
        let scriptJs = try! String(contentsOf: scriptJsUrl)
        let script = WKUserScript(source: scriptJs, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(script)
        
        let config = WKWebViewConfiguration()
        config.processPool = self.processPool
        config.userContentController = controller;
        
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        self.webView.navigationDelegate = self.webViewDelegate
        
        hostView.insertSubview(self.webView, at: 0)
    }
    
    // MARK: API calls
    
    func callMethod(_ methodOnObject: String, parameters: [String], callback: @escaping JsApiResultCallback) {
        var methodParams = [MethodParameter]()
        for param in parameters {
            methodParams.append(MethodParameter(plainValue: param))
        }
        callMethod(methodOnObject, methodParameters: methodParams, callback: callback)
    }
    
    func callMethod(_ methodOnObject: String, methodParameters: [MethodParameter], callback: @escaping JsApiResultCallback) {
        loadApi { error in
            if error != nil {
                callback(false, ZeroKitError.apiLoadingError.nserrorValue)
            } else {
                self.callMethodInner(methodOnObject, methodParameters: methodParameters, callback: callback)
            }
        }
    }
    
    private func callMethodInner(_ methodOnObject: String, methodParameters: [MethodParameter], callback: @escaping JsApiResultCallback) {
        let paramStr = InternalApi.parameterString(methodParameters)
        let callbackId = UUID().uuidString
        callbacks[callbackId] = callback
        
        let object: String
        if let lastDot = methodOnObject.range(of: ".", options: .backwards, range: nil, locale: nil) {
            object = methodOnObject.substring(to: lastDot.lowerBound)
        } else {
            object = "null"
        }
        
        var js = "ios_callApiMethod(\(object), \(methodOnObject), \"\(callbackId)\""
        if paramStr.characters.count > 0 {
            js.append(", \(paramStr)")
        }
        js.append(")")
        
        self.webView!.evaluateJavaScript(js) { (obj: Any?, error: Error?) in
            if error != nil {
                print("ZeroKit error evaluating javascript")
            }
        }
    }
    
    class private func parameterString(_ parameters: [MethodParameter]) -> String {
        var escapedParams = [String]()
        for param in parameters {
            escapedParams.append(String(format: "\"%@\"", param.value))
        }
        return escapedParams.joined(separator: ",")
    }
    
    class func escapeParameter(_ parameter: String) -> String {
        var escaped = ""
        
        for unicode in parameter.unicodeScalars {
            let val = unicode.value
            escaped.append(String(format: "\\u%04x", val))
        }
        
        return escaped;
    }
    
    func runJavascript(_ js: String, completion: ((Any?, Error?) -> Void)? = nil) {
        loadApi { error in
            if error != nil {
                completion?(nil, ZeroKitError.apiLoadingError.nserrorValue)
            } else {
                self.webView!.evaluateJavaScript(js, completionHandler: { (obj: Any?, error: Error?) in
                    completion?(obj, error)
                })
            }
        }
    }
    
    // MARK: API loading
    
    private func loadApi(completion: @escaping ErrorCallback) {
        if self.apiState == .didLoad {
            completion(nil)
            return
        }
        
        apiLoadCompletions.append(completion)
        enterState(.loading)
    }
    
    private func enterState(_ newState: ApiState, error: Error? = nil) {
        guard self.apiState != newState else {
            return
        }
        
        self.apiState = newState
        
        switch newState {
        case .notLoaded:
            NotificationCenter.default.post(name: ZeroKit.DidFailLoadingNotificationInner, object: zeroKit)
            runApiLoadCompletions(error: error ?? ZeroKitError.unknownError)
            
        case .loading:
            self.webView!.load(URLRequest(url: self.apiUrl))
            
        case .didLoad:
            NotificationCenter.default.post(name: ZeroKit.DidLoadNotificationInner, object: zeroKit)
            runApiLoadCompletions()
        }
    }
    
    private func runApiLoadCompletions(error: Error? = nil) {
        for completion in apiLoadCompletions {
            completion(error)
        }
        apiLoadCompletions.removeAll()
    }
    
    // MARK: Web view delegate
    
    private class WebViewDelegate: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        
        weak var internalApi: InternalApi?
        
        init(internalApi: InternalApi) {
            self.internalApi = internalApi
        }
        
        // MARK: WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let resultArray = message.body as! [AnyObject]
            let success: Bool = (resultArray[0] as! NSNumber).boolValue;
            let callbackId = resultArray[1] as! String
            let resultValue = resultArray[2]
            let callback = self.internalApi?.callbacks[callbackId]
            _ = self.internalApi?.callbacks.removeValue(forKey: callbackId)
            callback?(success, resultValue)
        }
        
        // MARK: WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("ZeroKit API loaded")
            self.internalApi?.enterState(.didLoad)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Failed loading ZeroKit API")
            self.internalApi?.enterState(.notLoaded, error: error)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Failed loading ZeroKit API")
            self.internalApi?.enterState(.notLoaded, error: error)
        }
    }
}
