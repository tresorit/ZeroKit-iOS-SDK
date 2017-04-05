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
         User registration:
         1. Init registration via the backend that uses the admin API.
         2. Register user through the SDK.
         3. Finish the registration calling the backend.
         4. The registration has to be validated using the validation code that is not returned by the backend. The server should send a verfication email to the user or validate through some other method.
        */
        
        AppDelegate.current.showProgress()
        
        /// Auto validate, so step 4 is automatically taken care of by the server.
        /// This applies to users whose username is in the format "test-user-{xyz}".
        let demoProfileData = "{ \"autoValidate\": true }"
        
        /// Step 1. You must initialize a user registration with an administrative call. You should ask your application backend to initialize the registration.
        AppDelegate.current.backend?.initRegistration(username: username, profileData: demoProfileData) { userId, regSessionId, error in
            
            guard error == nil else {
                self.showAlert("Error initializing user registration", message: "\(error!)")
                AppDelegate.current.hideProgress()
                return
            }
            
            /// Step 2. You register the user with their chosen password via ZeroKit, using the user ID received from the initRegistration call.
            AppDelegate.current.zeroKit!.register(withUserId: userId!, registrationId: regSessionId!, passwordField: self.passwordTextField) { regValidationVerifier, error in
                
                guard error == nil else {
                    AppDelegate.current.hideProgress()
                    self.showAlert("Sign up error", message: "\(error!)")
                    return
                }

                /// Step 3. Once the user is registered the registration validation verifier must be returned to the backend. It will be used to validate the user registration.
                AppDelegate.current.backend?.finishRegistration(userId: userId!, validationVerifier: regValidationVerifier!) { error in
                    
                    AppDelegate.current.hideProgress()
                    
                    guard error == nil else {
                        self.showAlert("Error initializing user registration", message: "\(error!)")
                        return
                    }
                    
                    self.showAlert("Successfully registered user \(username). You can now sign in.")
                    
                    /// Step 4. User validation is handled by the backend.
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }
}
