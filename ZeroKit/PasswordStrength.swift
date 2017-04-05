import Foundation

/**
 The zxcvbn score of the password.
 */
@objc public enum PasswordScore: Int {
    /** Risky password */
    case tooGuessable = 0
    
    /** Protection from throttled online attacks */
    case veryGuessable
    
    /** Protection from unthrottled online attacks */
    case somewhatGuessable
    
    /** Moderate protection from offline slow-hash scenario */
    case safelyUnguessable
    
    /** Strong protection from offline slow-hash scenario */
    case veryUnguessable
}

/**
 The time required to crack the password in different scenarios.
 */
public class PasswordCrackTimes: NSObject {
    
    /** Crack time in seconds for offline hashing 1e10 per second */
    public let offlineFastHashing: Double
    
    /** Crack time in seconds for offline hashing 1e4 per second */
    public let offlineSlowHashing: Double
    
    /** Crack time in seconds for online 10 per second */
    public let onlineNoThrottling: Double
    
    /** Crack time in seconds for online 100 per hour */
    public let onlineThrottling: Double
    
    init(offlineFastHashing: Double, offlineSlowHashing: Double, onlineNoThrottling: Double, onlineThrottling: Double) {
        self.offlineFastHashing = offlineFastHashing
        self.offlineSlowHashing = offlineSlowHashing
        self.onlineNoThrottling = onlineNoThrottling
        self.onlineThrottling = onlineThrottling
    }
}

/**
 It shows the length and the strength of the passwords, gives estimates of the number of guesses and time required to crack the password. We calculate this by running zxcvbn (https://github.com/dropbox/zxcvbn).
 */
public class PasswordStrength: NSObject {
    
    /**
     Score that represents the esitamted strength of the password.
     */
    public let score: PasswordScore
    
    /**
     Shows the length of the password.
     */
    public let length: Int
    
    /**
     The log10 of the estimated number of guesses needed to crack the password.
     */
    public let guessesLog10: Double
    
    /**
     Crack time estimates.
     */
    public let crackTimes: PasswordCrackTimes
    
    /**
     A warning provided by the library that explains what's wrong with the password, eg. 'This is a top-10 common password'.
     */
    public let warning: String?
    
    /**
     Some suggestions provided by the library to improve the password.
     */
    public let suggestions: [String]?
    
    init?(strengthDictionary dict: [String: Any]) {
        guard let scoreInt = (dict["score"] as? NSNumber)?.intValue,
            let score = PasswordScore(rawValue: scoreInt),
            let length = (dict["password"] as? NSString)?.length,
            let guessesLog10 = (dict["guesses_log10"] as? NSNumber)?.doubleValue,
            let timesDict = dict["crack_times_seconds"] as? [String: NSNumber],
            let offlineFastHashing = timesDict["offline_fast_hashing_1e10_per_second"]?.doubleValue,
            let offlineSlowHashing = timesDict["offline_slow_hashing_1e4_per_second"]?.doubleValue,
            let onlineNoThrottling = timesDict["online_no_throttling_10_per_second"]?.doubleValue,
            let onlineThrottling = timesDict["online_throttling_100_per_hour"]?.doubleValue else {
                
                return nil;
        }
        
        self.score = score
        self.length = length
        self.guessesLog10 = guessesLog10
        self.crackTimes = PasswordCrackTimes(offlineFastHashing: offlineFastHashing,
                                             offlineSlowHashing: offlineSlowHashing,
                                             onlineNoThrottling: onlineNoThrottling,
                                             onlineThrottling: onlineThrottling)
        
        let feedback = dict["feedback"] as? [String: Any]
        self.warning = feedback?["warning"] as? String
        self.suggestions = feedback?["suggestions"] as? [String]
    }
}
