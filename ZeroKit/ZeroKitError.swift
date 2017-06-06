import Foundation
import JavaScriptCore


/**
 Errors returned by ZeroKit.
 */
@objc public enum ZeroKitError: Int, Error {
    
    /** An unknown error occurred. */
    case unknownError = 1
    
    /** The result received is of unexpected type or format. */
    case unexpectedResult
    
    /** The data was not in the expected format. */
    case dataFormatError
    
    /** ZeroKit iOS SDK uses web view for the identity provider (IDP) funcionality. It performs the operation in a web view that is added as the bottom most view to the app's window. In most cases it should not cause any trouble. */
    case cannotAddWebView
    
    /** The provided password is empty. */
    case passwordIsEmpty
    
    /** Login by 'remember be' is not possible. Eg. the user did not log in previously with 'remember me'. */
    case cannotLoginByRememberMe
    
    /** Invalid authorization, ie. the password is incorrect. */
    case invalidAuthorization
    
    /** User with the specified user ID does not exist. */
    case userDoesNotExist
    
    /** The user is already member of the tresor. */
    case alreadyMember
    
    /** The user is not member of the tresor. */
    case notMember
    
    /** The caller user is not member of the tresor. */
    case callerUserIsNotMemberOfTresor
    
    /** Received invalid input. */
    case badInput
    
    /** Invalid user ID was provided. */
    case invalidUserId
    
    /** A network error occurred. */
    case networkError
    
    /** The response is not valid, ie. response verification failed. */
    case invalidResponse
    
    /** The request is not valid. */
    case invalidRequest
    
    /** An internal error occurred. */
    case internalError
    
    /** User is not logged in. Login is required to perform the operation. */
    case loginRequired
    
    /** Failed to load ZeroKit API. */
    case apiLoadingError
    
    /** Request was interrupted by the user. */
    case userInterrupted
    
    /** Could not find tresor by ID. */
    case tresorNotExists
    
    /** This tresor has been deleted or rejected at creation. */
    case tresorAlreadyDeleted
    
    /** This tresor is not yet approved. */
    case tresorIsNotApproved
    
    /** The user is not logged in. */
    case notLoggedInError
    
    /** There is no user by that ID. */
    case userNotFound
    
    /** You cannot invite yourself to a tresor. */
    case cantInviteYourself
    
    /** You cannot kick yourself from a tresor. */
    case cantKickYourself
    
    /** Item not found for operation */
    case notFound
    
    /** Operation was not allowed. */
    case forbidden
    
    /** The user is not validated. */
    case userNotValidated
    
    /** There is a problem with the provided registration session ID. */
    case regSessionNotExists
    
    /** The registration session and user ID mismatch. */
    case userIdMismatch
    
    /** Bad password try limit exceeded. */
    case badPasswordTryLimitExceeded
    
    
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
    
    fileprivate static func error(from stringCode: String) -> ZeroKitError {
        switch stringCode {
        case "BadInput":
            return .badInput
        case "InvalidUserId":
            return .invalidUserId
        case "InternalError":
            return .internalError
        case "AlreadyMember":
            return .alreadyMember
        case "InvalidAuthorization":
            return .invalidAuthorization
        case "UserNameDoesntExist":
            return .userDoesNotExist
        case "NotMember":
            return .notMember
        case "CallerUserIsNotMemberOfTresor":
            return .callerUserIsNotMemberOfTresor
        case "TresorNotExists":
            return .tresorNotExists
        case "TresorAlreadyDeleted":
            return .tresorAlreadyDeleted
        case "TresorIsNotApproved":
            return .tresorIsNotApproved
        case "NotLoggedInError":
            return .notLoggedInError
        case "UserNotFound":
            return .userNotFound
        case "CantInviteYourself":
            return .cantInviteYourself
        case "CantKickYourself":
            return .cantKickYourself
        case "NotFound":
            return .notFound
        case "Forbidden":
            return .forbidden
        case "UserNotValidated":
            return .userNotValidated
        case "RegSessionNotExists":
            return .regSessionNotExists
        case "UserIdMismatch":
            return .userIdMismatch
        case "BadPasswordTryLimitExceeded":
            return .badPasswordTryLimitExceeded
        default:
            Log.v("Unexpected error code: %@", stringCode)
            return .unknownError
        }
    }
    
    public static func ==(lhs: ZeroKitError, rhs: Error) -> Bool {
        guard let zkRhs = rhs as? ZeroKitError else {
            return false
        }
        
        return lhs.rawValue == zkRhs.rawValue
    }
}


public func ==<T: Error>(lhs: T, rhs: ZeroKitError) -> Bool {
    return rhs == lhs
}


extension NSError {
    convenience init(_ result: Any?, defaultErrorCode: ZeroKitError = .unknownError, message: String? = nil, line: Int = #line, file: String = #file) {
        var code = defaultErrorCode
        let domain = (ZeroKitError.unknownError as NSError).domain
        var info = [AnyHashable: Any]()
        var description: String?
        
        if let error = result as? ZeroKitError {
            code = error
            info[NSUnderlyingErrorKey] = result as! NSError // Keep userInfo dictionary
        } else if let error = result as? NSError {
            info[NSUnderlyingErrorKey] = error
        } else if let value = result as? JSValue {
            (code, description) = ZeroKitError.errorCodeFromJavascript(value)
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
