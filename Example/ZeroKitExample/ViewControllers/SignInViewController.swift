import UIKit
import ZeroKit

class SignInViewController: UIViewController {
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: ZeroKitPasswordField!
    @IBOutlet weak var signInButton: UIButton!
    
    @IBAction func signInButtonTap(_ sender: AnyObject) {
        self.view.endEditing(true)
        
        guard let username = usernameTextField.text, !passwordTextField.isEmpty else {
            self.showAlert("Username and password must not be empty")
            return
        }
        
        guard let userId = AppDelegate.current.mockApp!.db.userIdForUsername(username) else {
            self.showAlert("User not registered")
            return
        }
        
        AppDelegate.current.showProgress()
        
        AppDelegate.current.zeroKit?.login(withUserId: userId, passwordField: passwordTextField, rememberMe: false) { error in
            AppDelegate.current.hideProgress()
            
            guard error == nil else {
                self.showAlert("Sign in error", message: "\(error!)")
                return
            }
            
            AppDelegate.current.showAfterSigninScreen()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }
}
