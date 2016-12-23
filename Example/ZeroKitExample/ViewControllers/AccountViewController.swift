import UIKit

class AccountViewController: UIViewController {
    @IBOutlet weak var usernameLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.usernameLabel.text = nil
        AppDelegate.current.zeroKit?.whoAmI { userId, error in
            if userId != nil {
                if let username = AppDelegate.current.mockApp?.db.usernameForUserId(userId!) {
                    self.usernameLabel.text = "\(username)\n(\(userId!))"
                }
            }
        }
    }
    
    @IBAction func signOutButtonTap(_ sender: AnyObject) {
        AppDelegate.current.zeroKit?.logout { (result) -> (Void) in
            AppDelegate.current.showSigninScreen()
        }
    }
}
