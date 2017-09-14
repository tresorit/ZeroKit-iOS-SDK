import Foundation
import JavaScriptCore


/**
 Errors returned by ZeroKit.
 */
@objc public enum ZeroKitError: Int, Error {
    
    /** An unknown error occurred. */
    case unknownError = 1
    
    /** The result received is of unexpected type or format. */
    case unexpectedResult = 2
    
    /** The data was not in the expected format. */
    case dataFormatError = 3
    
    /** ZeroKit iOS SDK uses web view for the identity provider (IDP) funcionality. It performs the operation in a web view that is added as the bottom most view to the app's window. In most cases it should not cause any trouble. */
    case cannotAddWebView = 4
    
    /** The provided password is empty. */
    case passwordIsEmpty = 5
    
    /** Login by 'remember be' is not possible. Eg. the user did not log in previously with 'remember me'. */
    case cannotLoginByRememberMe = 6
    
    /** Invalid authorization, ie. the password is incorrect. */
    case invalidAuthorization = 7
    
    /** User with the specified user ID does not exist. */
    case userDoesNotExist = 8
    
    /** The user is already member of the tresor. */
    case alreadyMember = 9
    
    /** The user is not member of the tresor. */
    case notMember = 10
    
    /** The caller user is not member of the tresor. */
    case callerUserIsNotMemberOfTresor = 11
    
    /** Received invalid input. */
    case badInput = 12
    
    /** Invalid user ID was provided. */
    case invalidUserId = 13
    
    /** A network error occurred. */
    case networkError = 14
    
    /** The response is not valid, ie. response verification failed. */
    case invalidResponse = 15
    
    /** The request is not valid. */
    case invalidRequest = 16
    
    /** An internal error occurred. */
    case internalError = 17
    
    /** User is not logged in. Login is required to perform the operation. */
    case loginRequired = 18
    
    /** Failed to load ZeroKit API. This can happen, for example, when a network error occurs. You can retry the request when you get this error. */
    case apiLoadingError = 19
    
    /** Request was interrupted by the user. */
    case userInterrupted = 20
    
    /** Could not find tresor by ID. */
    case tresorNotExists = 21
    
    /** This tresor has been deleted or rejected at creation. */
    case tresorAlreadyDeleted = 22
    
    /** This tresor is not yet approved. */
    case tresorIsNotApproved = 23
    
    /** The user is not logged in. */
    case notLoggedInError = 24
    
    /** There is no user by that ID. */
    case userNotFound = 25
    
    /** You cannot invite yourself to a tresor. */
    case cantInviteYourself = 26
    
    /** You cannot kick yourself from a tresor. */
    case cantKickYourself = 27
    
    /** Item not found for operation */
    case notFound = 28
    
    /** Operation was not allowed. */
    case forbidden = 29
    
    /** The user is not validated. */
    case userNotValidated = 30
    
    /** There is a problem with the provided registration session ID. */
    case regSessionNotExists = 31
    
    /** The registration session and user ID mismatch. */
    case userIdMismatch = 32
    
    /** Bad password try limit exceeded. */
    case badPasswordTryLimitExceeded = 33
    
    /** User is already registered. */
    case userAlreadyRegistered = 34
    
    /** User does not exist */
    case userNotExists = 35
    
    fileprivate static func errorCodeFromJavascript(_ value: JSValue) -> (ZeroKitError, String?) {
        if let dict = value.toDictionary() {
            return self.errorCodeFromDictionary(dict)
        }
        return (.unknownError, nil)
    }
    
    fileprivate static func errorCodeFromDictionary(_ value: [AnyHashable: Any]) -> (ZeroKitError, String?) {
        if let code = value["code"] as? String {
            let description = self.description(from: value as? [NSObject: NSObject])
            
            if code == "InternalError" {
                if let internalException = value["internalException"] as? [AnyHashable: Any],
                    let internalCode = internalException["code"] as? String {
                    return (error(from: internalCode), description)
                }
            }
            return (error(from: code), description)
        }
        return (.unknownError, nil)
    }
    
    private static func description(from dict: [NSObject: NSObject]?) -> String? {
        guard let dict = dict else {
            return nil
        }
        
        var entries = [String]()
        for (key, value) in dict {
            if let value = value as? [NSObject: NSObject] {
                entries.append(String(format: "%@: %@", key, self.description(from: value)!))
            } else {
                entries.append(String(format: "%@: %@", key, value))
            }
        }
        return String(format: "{ %@ }", entries.joined(separator: ", "))
    }
    
    private static let errorMap: [String: ZeroKitError] = [
        "AlreadyAMember": .alreadyMember,
        "AlreadyMember": .alreadyMember,
        "BadInput": .badInput,
        "BadPasswordTryLimitExceeded": .badPasswordTryLimitExceeded,
        "CallerUserIsNotMemberOfTresor": .callerUserIsNotMemberOfTresor,
        "CantInviteYourself": .cantInviteYourself,
        "CantKickYourself": .cantKickYourself,
        "Forbidden": .forbidden,
        "InternalError": .internalError,
        "InvalidAuthorization": .invalidAuthorization,
        "InvalidUserId": .invalidUserId,
        "NotFound": .notFound,
        "NotLoggedInError": .notLoggedInError,
        "NotMember": .notMember,
        "RegSessionNotExists": .regSessionNotExists,
        "TresorAlreadyDeleted": .tresorAlreadyDeleted,
        "TresorIsNotApproved": .tresorIsNotApproved,
        "TresorNotExists": .tresorNotExists,
        "UserAlreadyRegistered": .userAlreadyRegistered,
        "UserIdMismatch": .userIdMismatch,
        "UserNameDoesntExist": .userDoesNotExist,
        "UserNotExists": .userNotExists,
        "UserNotFound": .userNotFound,
        "UserNotValidated": .userNotValidated,
    ]
    
    fileprivate static func error(from stringCode: String) -> ZeroKitError {
        if let error = errorMap[stringCode] {
            return error
        }
        Log.v("Unexpected error code: %@", stringCode)
        return .unknownError
    }
    
    public static func ==(lhs: ZeroKitError, rhs: Error) -> Bool {
        guard let zkRhs = rhs as? ZeroKitError else {
            return false
        }
        
        return lhs.rawValue == zkRhs.rawValue
    }
    
    // MARK: Format test support
    static func errorCodeString(for error: NSError) -> String {
        var inverseMap = [ZeroKitError: String]()
        for (key, value) in ZeroKitError.errorMap {
            inverseMap[value] = key
        }
        if let zkError = error as? ZeroKitError,
            let code = inverseMap[zkError] {
            return code
        }
        return "UnexpectedError \(error)"
    }
}


public func ==<T: Error>(lhs: T, rhs: ZeroKitError) -> Bool {
    return rhs == lhs
}


extension NSError {
    convenience init(_ result: Any?, defaultErrorCode: ZeroKitError = .unknownError, message: String? = nil, line: Int = #line, file: String = #file) {
        var code = defaultErrorCode
        let domain = (ZeroKitError.unknownError as NSError).domain
        var info = [String: Any]()
        var description: String?
        
        func handle(error: NSError) {
            if let zkError = error as? ZeroKitError {
                code = zkError
            }
            info[NSUnderlyingErrorKey] = error
        }
        
        if let error = result as? NSError {
            handle(error: error)
        } else if let value = result as? JSValue {
            if let error = value.toObject() as? NSError {
                handle(error: error)
            } else {
                (code, description) = ZeroKitError.errorCodeFromJavascript(value)
            }
        } else if let value = result as? [AnyHashable: Any] {
            (code, description) = ZeroKitError.errorCodeFromDictionary(value)
        } else if let value = result as? String {
            code = ZeroKitError.error(from: value)
            description = value
        }
        
        if let message = message {
            info["ZeroKitErrorMessage"] = message
        }
        if let description = description {
            info["ZeroKitErrorDescription"] = description
        }
        info["ZeroKitErrorOrigin"] = String(format: "%@:%d", (file as NSString).lastPathComponent, line)
        
        self.init(domain: domain, code: code.rawValue, userInfo: info)
        
        Log.v("Error created: %@", self.description)
    }
}
