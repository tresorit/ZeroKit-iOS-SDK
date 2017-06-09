import JavaScriptCore
import Security

class InternalApi: NSObject {

    typealias JsApiResultCallback = (/*success:*/ Bool, /*result:*/ JSValue) -> Void
    typealias ErrorCallback = (NSError?) -> Void
    
    private enum ApiState {
        case notLoaded
        case loading
        case didLoad
    }
    
    let config: ZeroKitConfig
    let localStorage = MapStorage()
    let sessionStorage = MapStorage()
    let persistenceKeys = PersistenceKeys()
    let srp = Srp()
    private var context: JSContext!
    private let urlSession = URLSession(configuration: URLSessionConfiguration.default)
    private var apiState = ApiState.notLoaded
    private var callbacks = [String: JsApiResultCallback]()
    private var apiLoadCompletions = [ErrorCallback]()
    private let queue = DispatchQueue(label: "com.tresorit.zerokit.internal", qos: .default, attributes: [])
    
    init(with config: ZeroKitConfig) {
        self.config = config
        super.init()
        loadApi { _ in }
    }
    
    // MARK: API calls
    
    func callMethod(_ methodOnObject: String, parameters: [Any], callback: @escaping JsApiResultCallback) {
        loadApi { error in
            if error != nil {
                callback(false, JSValue(undefinedIn: self.context))
            } else {
                self.callMethodInner(methodOnObject, parameters: parameters, callback: callback)
            }
        }
    }
    
    func callMethodInner(_ methodOnObject: String, parameters: [Any], callback: @escaping JsApiResultCallback) {
        
        let callbackId = UUID().uuidString
        self.callbacks[callbackId] = callback
        
        queue.async {
            let jsParams = JSValue(newArrayIn: self.context)!
            for (index, param) in parameters.enumerated() {
                jsParams.setObject(param, atIndexedSubscript: index)
            }
            
            let method = self.context.evaluateScript(methodOnObject)!
            let object: Any
            
            if let lastDot = methodOnObject.range(of: ".", options: .backwards, range: nil, locale: nil) {
                let objectName = methodOnObject.substring(to: lastDot.lowerBound)
                object = self.context.evaluateScript(objectName)!
            } else {
                object = NSNull()
            }
            
            let function = self.context.evaluateScript("ios_callApiMethod")!
            _ = function.call(withArguments: [object, method, callbackId, jsParams])
        }
    }
    
    func freeSrpMemory() {
        self.srp.cleanUpClients()
    }
    
    func zxcvbn(password: String, completion: @escaping (JSValue) -> Void) {
        queue.async {
            let function = self.context.evaluateScript("zxcvbn")!
            let result = function.call(withArguments: [password])!
            
            DispatchQueue.main.async {
                completion(result)
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
    
    private func enterState(_ newState: ApiState, error: NSError? = nil) {
        if self.apiState == newState {
            return
        }
        
        self.apiState = newState
        
        switch newState {
        case .notLoaded:
            let errorResult = error ?? NSError(ZeroKitError.unknownError)
            Log.e("Error loading API: %@", errorResult)
            runApiLoadCompletions(error: error)
            
        case .loading:
            self.loadJs { error in
                self.enterState(error == nil ? .didLoad : .notLoaded, error: error)
            }
            
        case .didLoad:
            Log.i("API loaded")
            runApiLoadCompletions()
        }
    }
    
    private func runApiLoadCompletions(error: NSError? = nil) {
        for completion in apiLoadCompletions {
            completion(error)
        }
        apiLoadCompletions.removeAll()
    }
    
    private func loadJs(completion: @escaping ErrorCallback) {
        queue.async {
            self.setupContext()
            
            var outError: NSError?
            
            do {
                for url in self.config.apiJsUrls {
                    let js = try String(contentsOf: url)
                    self.context.evaluateScript(js, withSourceURL: url)
                }
            } catch {
                outError = NSError(error, defaultErrorCode: .apiLoadingError)
            }
            
            DispatchQueue.main.async {
                if let error = outError {
                    completion(error)
                } else {
                    self.setBaseUrl { error in
                        completion(outError)
                    }
                }
            }
        }
    }
    
    private func setupContext() {
        if context != nil {
            return
        }
        
        context = JSContext()!
        context.name = "ZeroKit JSContext"
        
        context.exceptionHandler = { [weak self] (context: JSContext?, exception: JSValue?) -> Void in
            if let exception = exception {
                Log.e("Javascript Exception: %@, %@", exception.toString()!, exception.toObject()! as! CVarArg)
                
                DispatchQueue.main.async {
                    if let callbacks = self?.callbacks.values {
                        self?.callbacks.removeAll()
                        
                        for callback in callbacks {
                            callback(false, exception)
                        }
                    }
                }
            }
        }
        
        let logCallback: @convention(block) (JSValue, JSValue) -> Void = { level, args in
            let logLevel = ZeroKitLogLevel(jsLogLevel: level.toString() ?? "")
            
            if let obj = args.toObject() as? CVarArg {
                Log.log(level: logLevel, format: "Javascript Log: %@", args: obj)
            } else if let str = args.toString() {
                Log.log(level: logLevel, format: "Javascript Log: %@", args: str)
            } else {
                Log.log(level: logLevel, format: "Javascript Log unexpected type")
            }
        }
        context.setObject(logCallback as Any, forKeyedSubscript: "LogCallback" as NSString)
        
        let setTimeout: @convention(block) (JSValue, Int) -> Void = { [weak self] (function, timeout) in
            self?.queue.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(timeout), execute: {
                function.call(withArguments: [])
            })
        }
        context.setObject(setTimeout as Any, forKeyedSubscript: "setTimeout" as NSString)
        
        let resultCallback: @convention(block) (Bool, String, JSValue) -> Void = { [weak self] success, callbackId, result in
            DispatchQueue.main.async {
                let callback = self?.callbacks.removeValue(forKey: callbackId)
                callback?(success, result)
            }
        }
        context.setObject(resultCallback as Any, forKeyedSubscript: "ZeroKitResultCallback" as NSString)
        
        let xhrCallback: @convention(block) (JSValue, JSValue, JSValue, JSValue, JSValue) -> Void = { [weak self] method, url, headers, bodyBase64, completionCallback in
            let defaultHeaders = [AnyHashable: Any]()
            let defaultStatus = 0
            let defaultData = NSNull()
            
            guard let urlSession = self?.urlSession else {
                Log.v("XHR request for url %@ failed.", url.toString() ?? "<nil>")
                completionCallback.call(withArguments: [defaultHeaders, defaultStatus, defaultData])
                return
            }
            
            let request = NSMutableURLRequest(url: URL(string: url.toString()!)!)
            request.httpMethod = method.toString()!
            
            var headersMap = [String: String]()
            for keyValue in headers.toArray() as! [[String]] {
                headersMap[keyValue[0]] = keyValue[1]
            }
            request.allHTTPHeaderFields = headersMap
            
            if bodyBase64.isString {
                request.httpBody = Data(base64Encoded: bodyBase64.toString()!)!
            }
            
            let startDate = Date()
            
            if Log.shouldLog(.verbose) {
                var bodyString = "<nil>"
                if let body = request.httpBody {
                    bodyString = String(data: body, encoding: .utf8) ?? bodyBase64.toString() ?? bodyString
                }
                Log.v("XHR request url: %@, method: %@, headers: %@, body: %@", url.toString()!, method.toString()!, headersMap, bodyString)
            }
            
            let task = urlSession.dataTask(with: request as URLRequest) { (data, response, error) in
                let httpResponse = response as? HTTPURLResponse
                let responseData = data?.base64EncodedString()
                
                if Log.shouldLog(.verbose) {
                    let duration = Date().timeIntervalSince(startDate)
                    var dataStr = "<nil>"
                    if let data = data {
                        dataStr = String(data: data, encoding: .utf8) ?? dataStr
                    }
                    
                    if let error = error as NSError? {
                        Log.v("XHR response (%.2fs) error: %@", duration, error)
                    } else {
                        Log.v("XHR response (%.2fs) url: %@, status code: %d, headers: %@, data: %@", duration, httpResponse?.url?.absoluteString ?? "<nil>", httpResponse?.statusCode ?? 0, httpResponse?.allHeaderFields ?? "<nil>", dataStr)
                    }
                }
                
                completionCallback.call(withArguments: [httpResponse?.allHeaderFields ?? defaultHeaders,
                                                        httpResponse?.statusCode ?? defaultStatus,
                                                        (responseData as Any?) ?? defaultData])
            }
            
            task.resume()
        }
        context.setObject(xhrCallback as Any, forKeyedSubscript: "XHRCallbackInner" as NSString)
        
        context.setObject(localStorage, forKeyedSubscript: "mockLocalStorage" as NSString)
        context.setObject(sessionStorage, forKeyedSubscript: "mockSessionStorage" as NSString)
        context.setObject(persistenceKeys, forKeyedSubscript: "mockPersistenceKeys" as NSString)
        context.setObject(Crypto(), forKeyedSubscript: "iosCrypto" as NSString)
        context.setObject(srp, forKeyedSubscript: "iosSrp" as NSString)
    }
    
    private func setBaseUrl(completion: @escaping ErrorCallback) {
        queue.async {
            let function = self.context.evaluateScript("mobileCommands.setBaseURL")!
            let result = function.call(withArguments: [self.config.apiBaseUrl.absoluteString])
            
            Log.v("Set base url: %@", result?.toObject() as? CVarArg ?? "Unexpected value")
            
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
}
