import UIKit

class AccountViewController: UIViewController {
    @IBOutlet weak var usernameLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.usernameLabel.text = nil
        
        AppDelegate.current.zeroKit?.whoAmI { userId, error in
            if userId != nil {
                self.usernameLabel.text = "User ID: \(userId!)"
            }
        }
    }
    
    @IBAction func signOutButtonTap(_ sender: AnyObject) {
        AppDelegate.current.backend?.forgetToken()
        AppDelegate.current.zeroKit?.logout { (result) -> (Void) in
            AppDelegate.current.showSigninScreen()
        }
    }
}
