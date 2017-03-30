import Foundation


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
    
    /** ZeroKit iOS SDK wraps our javascript based SDK which means it needs a web view to provide a runtime environment. This web view is added as the bottom most view to the app's window. In most cases it should not cause any trouble. Please init ZeroKit after application window is created. */
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
    
    static func from(_ result: Any?) -> ZeroKitError {
        if let error = result as? ZeroKitError {
            return error
        }
        
        guard let dict = result as? [AnyHashable: AnyObject],
            let code = dict["code"] as? String else {
                return .unexpectedResult
        }
        
        switch code {
        case "BadInput":
            return .badInput
        case "InvalidUserId":
            return .invalidUserId
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
        default:
            return .unknownError
        }
    }
    
    var nserrorValue: NSError {
        return self as NSError
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
