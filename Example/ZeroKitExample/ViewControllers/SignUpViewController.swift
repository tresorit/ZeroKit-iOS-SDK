import UIKit
import ZeroKit

class SignUpViewController: UIViewController {
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: ZeroKitPasswordField!
    @IBOutlet weak var passwordConfirmationTextField: ZeroKitPasswordField!
    @IBOutlet weak var signUpButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        passwordTextField.matchingField = passwordConfirmationTextField
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
