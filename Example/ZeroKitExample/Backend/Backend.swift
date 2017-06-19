//
//  Backend.swift
//  ZeroKitExample
//
//  Created by László Agárdi on 2017. 02. 27..
//  Copyright © 2017. Tresorit Kft. All rights reserved.
//

import UIKit
import ZeroKit

public enum BackendError: Int, Error {
    case unknownError = 1
    case notImplemented
    case authorizationRequired
}

public class Backend: NSObject {
    public typealias AuthorizationCredentialsCallback = (/*auth code*/ String?, /*client ID*/ String?, Error?) -> Void
    public typealias AuthorizationCallback = (@escaping AuthorizationCredentialsCallback) -> Void
    
    public let baseUrl: URL
    private var token: String?
    private let urlSession: URLSession
    private let authorizationCallback: AuthorizationCallback?
    
    public init(withBackendBaseUrl url: URL, authorizationCallback: AuthorizationCallback?) {
        self.baseUrl = url
        self.urlSession = URLSession(configuration: URLSessionConfiguration.default)
        self.authorizationCallback = authorizationCallback
    }
    
    // MARK: No auth calls
    
    public func getUserId(forUsername username: String, completion: @escaping (String?, Error?) -> Void) {
        call(httpMethod: "GET",
             path: "api/user/get-user-id",
             queryParams: ["userName": username],
             body: nil,
             needsAuth: false) { userId, error in
                
                completion(userId as? String, error)
        }
    }
    
    public func initRegistration(username: String, profileData: String, completion: @escaping (/*userId:*/ String?, /*regSessionId:*/ String?, Error?) -> Void) {
        call(httpMethod: "POST",
             path: "api/user/init-user-registration",
             queryParams: nil,
             body: ["userName": username, "profileData": profileData],
             needsAuth: false) { json, error in
                
                guard let dict = json as? [String: String],
                    let userId = dict["userId"],
                    let regSessionId = dict["regSessionId"],
                    error == nil else {
                        
                        completion(nil, nil, error ?? BackendError.unknownError)
                        return
                }
                
                completion(userId, regSessionId, nil)
        }
    }
    
    public func finishRegistration(userId: String, validationVerifier: String, completion: @escaping (Error?) -> Void) {
        call(httpMethod: "POST",
             path: "api/user/finish-user-registration",
             queryParams: nil,
             body: ["userId": userId, "validationVerifier": validationVerifier],
             needsAuth: false) { json, error in
                
                completion(error)
        }
    }
    
    public func validateUser(userId: String, validationCode: String, completion: @escaping (Error?) -> Void) {
        call(httpMethod: "POST",
             path: "api/user/validate-user",
             queryParams: nil,
             body: ["userId": userId, "validationCode": validationCode],
             needsAuth: false) { json, error in
                
                completion(error)
        }
    }
    
    // MARK: Authorization
    
    public func login(authorizationCode: String, clientId: String, completion: @escaping (Error?) -> Void) {
        call(httpMethod: "POST",
             path: "api/auth/login-by-code",
             queryParams: ["clientId": clientId, "token": "true"],
             body: ["code": authorizationCode],
             needsAuth: false) { [weak self] json, error in
                
                guard let dict = json as? [String: Any],
                    let token = dict["id"] as? String,
                    error == nil else {
                        
                        completion(error ?? BackendError.unknownError)
                        return
                }
                
                self?.token = token
                completion(nil)
        }
    }
    
    public func forgetToken() {
        token = nil
    }
    
    // MARK: Calls requiring auth
    
    public func createdTresor(tresorId: String, completion: @escaping (Error?) -> Void) {
        call(httpMethod: "POST",
             path: "api/tresor/created",
             queryParams: nil,
             body: ["tresorId": tresorId],
             needsAuth: true) { json, error in
                
                completion(error)
        }
    }
    
    public func sharedTresor(operationId: String, completion: @escaping (Error?) -> Void) {
        call(httpMethod: "POST",
             path: "api/tresor/invited-user",
             queryParams: nil,
             body: ["operationId": operationId],
             needsAuth: true) { json, error in
                
                completion(error)
        }
    }
    
    public func kickedUser(operationId: String, completion: @escaping (Error?) -> Void) {
        call(httpMethod: "POST",
             path: "api/tresor/kicked-user",
             queryParams: nil,
             body: ["operationId": operationId],
             needsAuth: true) { json, error in
                
                completion(error)
        }
    }
    
    public func createdInvitationLink(operationId: String, completion: @escaping (Error?) -> Void) {
        // TODO: approve link creation
        completion(BackendError.notImplemented)
    }
    
    public func acceptedInvitationLink(operationId: String, completion: @escaping (Error?) -> Void) {
        // TODO: approve link acceptence
        completion(BackendError.notImplemented)
    }
    
    public func getProfile(completion: @escaping (String?, Error?) -> Void) {
        call(httpMethod: "GET",
             path: "api/data/profile",
             queryParams: nil,
             body: nil,
             needsAuth: true) { str, error in
                
                completion(str as? String, error)
        }
    }
    
    public func setProfile(data: String, completion: @escaping (Error?) -> Void) {
        call(httpMethod: "POST",
             path: "api/data/profile",
             queryParams: nil,
             body: ["data": data],
             needsAuth: true) { json, error in
                
                completion(error)
        }
    }
    
    public func getPublicProfile(for userId: String, completion: @escaping (String?, Error?) -> Void) {
        call(httpMethod: "GET",
             path: "api/data/public-profile",
             queryParams: ["id": userId],
             body: nil,
             needsAuth: true) { str, error in
                
                completion(str as? String, error)
        }
    }
    
    public func storePublicProfile(data: String, completion: @escaping (Error?) -> Void) {
        call(httpMethod: "POST",
             path: "api/data/public-profile",
             queryParams: nil,
             body: ["data": data],
             needsAuth: true) { json, error in
                
                completion(error)
        }
    }
    
    public func store(data: String, withId id: String, inTresor tresoriId: String, completion: @escaping (Error?) -> Void) {
        call(httpMethod: "POST",
             path: "api/data/store",
             queryParams: ["id": id],
             body: ["tresorId": tresoriId, "data": data],
             needsAuth: true) { json, error in
                
                completion(error)
        }
    }
    
    public func getData(withId id: String, completion: @escaping (String?, Error?) -> Void) {
        call(httpMethod: "GET",
             path: "api/data/get",
             queryParams: ["id": id],
             body: nil,
             needsAuth: true) { str, error in
                
                completion(str as? String, error)
        }
    }
    
    // MARK: Making server requests
    
    private func call(httpMethod: String,
                      path: String,
                      queryParams: [String: String]?,
                      body: [String: String]?,
                      needsAuth: Bool,
                      completion: @escaping (Any?, Error?) -> Void) {
        
        let url = self.url(withPath: path, queryParameters: queryParams)
        
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = httpMethod
        
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                completion(nil, error)
                return
            }
        }
        
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let retryWithLoginIfCan = { [weak self] () -> Bool in
            guard let authCallback = self?.authorizationCallback else {
                return false
            }
            
            // Try to get auth token
            authCallback { [weak self] authCode, clientId, error in
                guard let authCode = authCode,
                    let clientId = clientId,
                    error == nil else {
                        
                        completion(nil, error ?? BackendError.authorizationRequired)
                        return
                }
                
                self?.login(authorizationCode: authCode, clientId: clientId) { error in
                    guard error == nil else {
                        completion(nil, error)
                        return
                    }
                    
                    self?.call(httpMethod: httpMethod,
                               path: path,
                               queryParams: queryParams,
                               body: body,
                               needsAuth: needsAuth,
                               completion: completion)
                }
            }
            
            return true
        }
        
        if needsAuth {
            if let token = self.token {
                request.addValue(String(format: "Bearer %@", token), forHTTPHeaderField: "Authorization")
                
            } else {
                if !retryWithLoginIfCan() {
                    completion(nil, BackendError.authorizationRequired)
                }
                return
            }
        }
        
        let dataTask = urlSession.dataTask(with: request as URLRequest) { (data: Data?, response: URLResponse?, error: Error?) in
            
            DispatchQueue.main.async {
                
                if let httpCode = (response as? HTTPURLResponse)?.statusCode, error == nil && 200 <= httpCode && httpCode < 300 {
                    
                    do {
                        if let data = data {
                            let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                            completion(json, nil)
                            
                        } else {
                            completion(nil, nil)
                        }
                    } catch {
                        completion(nil, error)
                    }
                    
                } else {
                    
                    if let data = data,
                        let str = String(data: data, encoding: .utf8),
                        str == "Unauthorized" {
                        
                        if !retryWithLoginIfCan() {
                            completion(nil, BackendError.authorizationRequired)
                        }
                        
                    } else {
                        completion(nil, error ?? BackendError.unknownError)
                    }
                }
            }
        }
        
        dataTask.resume()
    }
    
    private func url(withPath path: String, queryParameters parameters: [String: String]?) -> URL {
        var absoluteStr = self.baseUrl.appendingPathComponent(path).absoluteString
        
        if let parameters = parameters, parameters.count > 0 {
            let paramArray = parameters.reduce([String]()) { (acc: [String], item: (key: String, value: String)) -> [String] in
                var macc = acc
                macc.append(String(format: "%@=%@", item.key, item.value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!))
                return macc
            }
            
            absoluteStr = absoluteStr.appendingFormat("?%@", paramArray.joined(separator: "&"))
        }
        
        return URL(string: absoluteStr)!
    }
    
}
