import UIKit
import ZeroKit

class SignUpViewController: UIViewController, ZeroKitPasswordFieldDelegate {
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: ZeroKitPasswordField!
    @IBOutlet weak var passwordConfirmationTextField: ZeroKitPasswordField!
    @IBOutlet weak var passwordStrengthLabel: UILabel!
    @IBOutlet weak var passwordsMatchLabel: UILabel!
    @IBOutlet weak var signUpButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        passwordTextField.delegate = self
        passwordConfirmationTextField.delegate = self
        passwordTextField.matchingField = passwordConfirmationTextField
        
        checkPassword()
    }
    
    // Password field delegate
    func passwordFieldContentsChanged(_ passwordField: ZeroKitPasswordField) {
        checkPassword()
    }
    
    func checkPassword() {
        updatePasswordStrength()
        updatePasswordMatch()
    }
    
    func updatePasswordStrength() {
        AppDelegate.current.zeroKit!.passwordStrength(passwordField: passwordTextField) { strength, error in
            guard let strength = strength else {
                return
            }
            
            if strength.length == 0 {
                self.passwordStrengthLabel.text = nil
                return
            }
            
            switch strength.score {
            case .tooGuessable:
                self.passwordStrengthLabel.text = "Bad password"
                self.passwordStrengthLabel.textColor = UIColor(red: 226/255.0, green: 24/255.0, blue: 12/255.0, alpha: 1.0)
            case .veryGuessable:
                self.passwordStrengthLabel.text = "Weak password"
                self.passwordStrengthLabel.textColor = UIColor(red: 237/255.0, green: 123/255.0, blue: 24/255.0, alpha: 1.0)
            case .somewhatGuessable:
                self.passwordStrengthLabel.text = "Fair password"
                self.passwordStrengthLabel.textColor = UIColor(red: 237/255.0, green: 123/255.0, blue: 24/255.0, alpha: 1.0)
            case .safelyUnguessable:
                self.passwordStrengthLabel.text = "Good password"
                self.passwordStrengthLabel.textColor = UIColor(red: 80/255.0, green: 138/255.0, blue: 5/255.0, alpha: 1.0)
            case .veryUnguessable:
                self.passwordStrengthLabel.text = "Great password"
                self.passwordStrengthLabel.textColor = UIColor(red: 80/255.0, green: 138/255.0, blue: 5/255.0, alpha: 1.0)
            }
        }
    }
    
    func updatePasswordMatch() {
        if passwordTextField.isEmpty {
            self.passwordsMatchLabel.text = nil
            return
        }
        
        if passwordTextField.passwordsMatch {
            passwordsMatchLabel.text = "Passwords match"
            passwordsMatchLabel.textColor = UIColor(red: 80/255.0, green: 138/255.0, blue: 5/255.0, alpha: 1.0)
        } else {
            passwordsMatchLabel.text = "Passwords do not match"
            passwordsMatchLabel.textColor = UIColor(red: 226/255.0, green: 24/255.0, blue: 12/255.0, alpha: 1.0)
        }
    }
    
    @IBAction func signUpButtonTap(_ sender: AnyObject) {
        self.view.endEditing(true)
        
        guard let username = usernameTextField.text, !passwordTextField.isEmpty && !passwordConfirmationTextField.isEmpty else {
            self.showAlert("Username and password must not be empty")
            return
        }
        
        guard passwordTextField.passwordsMatch else {
            self.showAlert("Passwords do not match")
            return
        }
        
        /*
         3-step user registration:
         1. init registration
         2. register user through the SDK
         3. validate the user
        */
        
        AppDelegate.current.showProgress()
        
        /// Registering a user is a 3-step process:
        
        /// 1. You must initialize a user registration with the admin. You should send a request to your application's backend to do this.
        AppDelegate.current.mockApp?.initUserRegistration { (success, userId, regSessionId, regSessionVerifier) -> (Void) in
            guard success else {
                self.showAlert("Error initializing user registration")
                AppDelegate.current.hideProgress()
                return
            }
            
            /// 2. You register the user with their password via ZeroKit.
            AppDelegate.current.zeroKit?.register(withUserId: userId!, registrationId: regSessionId!, passwordField: self.passwordTextField) { regValidationVerifier, error in
                guard error == nil else {
                    AppDelegate.current.hideProgress()
                    self.showAlert("Sign up error", message: "\(error!)")
                    return
                }
                
                /// 3. Once the user is registered they must be validated with an admin call made by your backend.
                AppDelegate.current.mockApp?.validateUser(userId!, regSessionId: regSessionId!, regSessionVerifier: regSessionVerifier!, regValidationVerifier: regValidationVerifier!) { (success) -> (Void) in
                    
                    AppDelegate.current.hideProgress()
                    if success {
                        AppDelegate.current.mockApp?.db.saveUserId(userId!, forUsername: username)
                        self.showAlert("Successfully registered user \(username). You can now sign in.")
                    } else {
                        self.showAlert("Error validating user after registration")
                    }
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }
}
