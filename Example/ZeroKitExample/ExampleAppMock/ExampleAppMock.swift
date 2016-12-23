import Foundation

/** - IMPORTANT: The functionality of this class should be implemented by your application's backend. We provide a mock implementation here so the example app can be used without needing to set up a backend. */
class ExampleAppMock: NSObject {
    
    fileprivate typealias ApiCallback = (/*json:*/ Any?, /*error:*/ Error?) -> (Void)
    typealias RegistrationCallback = (/*success:*/ Bool, /*userId:*/ String?, /*regSessionId:*/ String?, /*regSessionVerifier:*/ String?) -> (Void)
    typealias SuccessCallback = (/*success:*/ Bool) -> (Void)
    
    fileprivate let adminUserId: String
    fileprivate let adminKey: String
    fileprivate let apiRoot: URL
    fileprivate let urlSession: URLSession
    
    let db = ExampleAppMockDatabase()
    
    override init() {
        /// If ExampleAppMock.plist file does not exist, then see ExampleAppMock.sample.plist and create your own.
        let bundle = Bundle(for: ExampleAppMock.classForCoder())
        let settingsUrl = bundle.url(forResource: "ExampleAppMock", withExtension: "plist")!
        let settings = NSDictionary(contentsOf: settingsUrl)!
        
        self.adminUserId = settings["AdminUserId"] as! String
        self.adminKey = settings["AdminKey"] as! String
        self.apiRoot = URL(string: settings["ApiRoot"] as! String)!
        self.urlSession = URLSession(configuration: URLSessionConfiguration.default)
    }
    
    fileprivate func apiCall(_ endpoint: String, jsonBody: Data?, completion: @escaping ApiCallback) {
        let url = self.apiRoot.appendingPathComponent(endpoint)
        let request = NSMutableURLRequest(url: url)
        request.httpBody = jsonBody
        request.httpMethod = jsonBody == nil ? "GET" : "POST"
        
        let headers = headersFor(url, httpMethod: request.httpMethod, body: jsonBody)
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        let dataTask = self.urlSession.dataTask(with: request as URLRequest, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
            DispatchQueue.main.async {
                let httpCode = (response as! HTTPURLResponse).statusCode
                if error == nil && 200 <= httpCode && httpCode < 300 {
                    
                    do {
                        let json: Any? = data != nil ? try JSONSerialization.jsonObject(with: data!, options: []) : nil
                        completion(json, nil)
                    } catch {
                        completion(nil, nil)
                    }
                    
                } else {
                    let apiCallError = error ?? NSError(domain: "ZeroKitExampleError", code: 1, userInfo: nil)
                    completion(nil, apiCallError)
                }
            }
        }) 
        
        dataTask.resume()
    }
    
    fileprivate func headersFor(_ url: URL, httpMethod: String, body: Data?) -> [String: String] {
        var headers = [String: String]()
        
        headers["UserId"] = self.adminUserId
        headers["TresoritDate"] = self.isoDateNow()
        
        if body != nil {
            headers["Content-Type"] = "application/json"
            headers["Content-SHA256"] = self.sha256(body!)
        }
        
        // HMAC headers
        var hmacHeaders = Array(headers.keys)
        hmacHeaders.append("HMACHeaders")
        headers["HMACHeaders"] = hmacHeaders.joined(separator: ",")
        
        var urlPath = url.path
        // truncate leading '/'
        urlPath = urlPath.substring(from: urlPath.index(urlPath.startIndex, offsetBy: 1))
        
        var headerStringToHash = httpMethod + "\n"
        headerStringToHash += urlPath + "\n"
        headerStringToHash += hmacHeaders.map({ key in
            return key + ":" + headers[key]!
        }).joined(separator: "\n")
        
        let hmacData = hmacSha256(self.adminKey, stringData: headerStringToHash)
        let hmacBase64 = hmacData.base64EncodedString(options: [])
        headers["Authorization"] = "AdminKey \(hmacBase64)"
        
        return headers
    }
    
    fileprivate func isoDateNow() -> String {
        let dateFormatter = DateFormatter()
        let enUSPosixLocale = Locale(identifier: "en_US_POSIX")
        dateFormatter.locale = enUSPosixLocale
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return dateFormatter.string(from: Date())
    }
    
    fileprivate func sha256(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256((data as NSData).bytes, CC_LONG(data.count), &hash)
        let out: NSMutableString = ""
        for val in hash {
            out.appendFormat("%02x", val)
        }
        return out as String
    }
    
    fileprivate func hmacSha256(_ hexKey: String, stringData: String) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        let key = hexToBytes(hexKey)
        let data = stringData.data(using: String.Encoding.utf8)!
        
        CCHmac(UInt32(kCCHmacAlgSHA256), (key as NSData).bytes, key.count, (data as NSData).bytes, data.count, &hash)
        
        return Data(bytes: &hash, count: Int(hash.count))
    }
    
    fileprivate func hexToBytes(_ inHexStr: String) -> Data {
        let hexStr: String
        if inHexStr.characters.count % 2 == 1 {
            hexStr = "0\(inHexStr)"
        } else {
            hexStr = inHexStr
        }
        
        let data = NSMutableData(capacity: hexStr.characters.count / 2)!
        
        for index in stride(from: 0, to: hexStr.characters.count, by: 2) {
            let start = hexStr.characters.index(hexStr.startIndex, offsetBy: index)
            let end = hexStr.characters.index(hexStr.startIndex, offsetBy: index + 2)
            let range = start ..< end
            var byte = UInt8(hexStr.substring(with: range), radix: 16)!
            data.append(&byte, length: 1)
        }
        
        return data as Data
    }
    
    // MARK: Example mock methods
    
    func initUserRegistration(_ completion: @escaping RegistrationCallback) {
        apiCall("api/v4/admin/user/init-user-registration", jsonBody: Data()) { (json, error) -> (Void) in
            if let dict = json as? [String: String] , error == nil {
                completion(true, dict["UserId"], dict["RegSessionId"], dict["RegSessionVerifier"])
            } else {
                completion(false, nil, nil, nil)
            }
        }
    }
    
    func validateUser(_ userId: String, regSessionId: String, regSessionVerifier: String, regValidationVerifier: String, completion: @escaping SuccessCallback) {
        let json = ["RegSessionId": regSessionId,
                    "RegSessionVerifier": regSessionVerifier,
                    "RegValidationVerifier": regValidationVerifier,
                    "UserId": userId]
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        
        apiCall("api/v4/admin/user/validate-user-registration", jsonBody: jsonData) { (json, error) -> (Void) in
            completion(error == nil)
        }
    }
    
    func approveTresorCreation(_ tresorId: String, approve: Bool, completion: @escaping SuccessCallback) {
        let json = ["TresorId": tresorId]
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        
        let endpoint = approve ? "api/v4/admin/tresor/approve-tresor-creation" : "api/v4/admin/tresor/reject-tresor-creation"
        apiCall(endpoint, jsonBody: jsonData) { (json, error) -> (Void) in
            completion(error == nil)
        }
    }
    
    func deleteTresor(_ tresorId: String, completion: @escaping SuccessCallback) {
        let json = ["TresorId": tresorId]
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        
        apiCall("api/v4/admin/tresor/delete-tresor", jsonBody: jsonData) { (json, error) -> (Void) in
            completion(error == nil)
        }
    }
    
    func approveShare(_ shareId: String, approve: Bool, completion: @escaping SuccessCallback) {
        let json = ["OperationId": shareId]
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        
        let endpoint = approve ? "api/v4/admin/tresor/approve-share" : "api/v4/admin/tresor/reject-share"
        apiCall(endpoint, jsonBody: jsonData) { (json, error) -> (Void) in
            completion(error == nil)
        }
    }
    
    func getShareDetails(_ shareId: String, completion: @escaping SuccessCallback) {
        apiCall("api/v4/admin/tresor/get-share-details?operationId=\(shareId)", jsonBody: nil) { (json, error) -> (Void) in
            completion(error == nil)
        }
    }
    
    func approveKick(_ kickId: String, approve: Bool, completion: @escaping SuccessCallback) {
        let json = ["OperationId": kickId]
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        
        let endpoint = approve ? "api/v4/admin/tresor/approve-kick" : "api/v4/admin/tresor/reject-kick"
        apiCall(endpoint, jsonBody: jsonData) { (json, error) -> (Void) in
            completion(error == nil)
        }
    }
    
    func approveCreateInvitationLink(_ operationId: String, approve: Bool, completion: @escaping SuccessCallback) {
        let json = ["OperationId": operationId]
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        
        let endpoint = approve ? "api/v4/admin/tresor/approve-invitation-link-creation" : "api/v4/admin/tresor/reject-invitation-link-creation"
        apiCall(endpoint, jsonBody: jsonData) { (json, error) -> (Void) in
            completion(error == nil)
        }
    }
    
    func approveAcceptInvitationLink(_ operationId: String, approve: Bool, completion: @escaping SuccessCallback) {
        let json = ["OperationId": operationId]
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        
        let endpoint = approve ? "api/v4/admin/tresor/approve-invitation-link-acception" : "api/v4/admin/tresor/reject-invitation-link-acception"
        apiCall(endpoint, jsonBody: jsonData) { (json, error) -> (Void) in
            completion(error == nil)
        }
    }
    
    func approveRevokeInvitationLink(_ operationId: String, approve: Bool, completion: @escaping SuccessCallback) {
        let json = ["OperationId": operationId]
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        
        let endpoint = approve ? "api/v4/admin/tresor/approve-invitation-link-revocation" : "api/v4/admin/tresor/reject-invitation-link-revocation"
        apiCall(endpoint, jsonBody: jsonData) { (json, error) -> (Void) in
            completion(error == nil)
        }
    }
}
