import UIKit

/**
 This class provides examples for:
 - tresor creation
 - encryption
 - decryption
 - tresor sharing
 */
class EncryptViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var createTresorStepView: StepContainerView!
    @IBOutlet weak var encryptTextStepView: StepContainerView!
    @IBOutlet weak var testDecryptStepView: StepContainerView!
    @IBOutlet weak var shareTresorStepView: StepContainerView!
    
    fileprivate var tresorId: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.disableStep(encryptTextStepView)
        self.disableStep(testDecryptStepView)
        self.disableStep(shareTresorStepView)
        
        self.tresorIdLabel.text = "Tresor ID: no tresor"
        self.plainTextLabel.text = nil
        self.shareResultLabel.text = nil
        
        let textInputBorderColor = UIColor.lightGray
        self.cipherTextView.setBorderWithColor(textInputBorderColor)
        self.plainTextView.setBorderWithColor(textInputBorderColor)
        self.usernameTextField.setBorderWithColor(textInputBorderColor)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardNotification), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardNotification), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    }
    
    func disableStep(_ stepView: UIView) {
        stepView.isUserInteractionEnabled = false
        stepView.alpha = 0.25
    }
    
    func enableStep(_ stepView: UIView) {
        stepView.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.5, animations: {
            stepView.alpha = 1.0
        }) 
    }
    
    func keyboardNotification(_ notification: Notification) {
        if notification.name == NSNotification.Name.UIKeyboardWillHide {
            self.scrollView.contentInset = UIEdgeInsets.zero
            return
        }
        
        let endFrame = ((notification as NSNotification).userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, endFrame.height, 0)
    }
    
    // MARK: Step 1: Create Tresor
    
    @IBAction func createTresorButtonTap(_ sender: AnyObject) {
        self.view.endEditing(true)
        
        AppDelegate.current.showProgress()
        
        /// 1. You create a tresor via the ZeroKit API.
        AppDelegate.current.zeroKit?.createTresor { tresorId, error in
            guard error == nil else {
                AppDelegate.current.hideProgress()
                self.showAlert("Error creating tresor", message: "\(error!)")
                return
            }
            
            /// 2. Tresor creation must be approved by an administrative call. You should send the tresor ID to your backend to approve its creation.
            AppDelegate.current.backend?.createdTresor(tresorId: tresorId!) { error in
                AppDelegate.current.hideProgress()
                if error == nil {
                    self.useTresor(tresorId!)
                } else {
                    self.showAlert("Error approving tresor creation")
                }
            }
        }
    }
    
    private func useTresor(_ tresorId: String) {
        self.tresorId = tresorId
        self.tresorIdLabel.text = "Tresor ID: \(tresorId)"
        enableStep(encryptTextStepView)
    }
    
    // MARK: Step 2: Encrypt
    
    @IBOutlet weak var plainTextView: UITextView!
    @IBOutlet weak var tresorIdLabel: UILabel!
    
    @IBAction func encryptButtonTap(_ sender: AnyObject) {
        self.view.endEditing(true)
        
        guard let text = self.plainTextView.text , text.characters.count > 0 else {
            self.showAlert("Please enter some text to encrypt")
            return
        }
        
        self.cipherTextView.text = nil
        
        /// Encrypt the entered text
        AppDelegate.current.zeroKit?.encrypt(plainText: text, inTresor: tresorId) { cipherText, error in
            guard error == nil else {
                self.showAlert("Error encrypting text", message: "\(error!)")
                return
            }
            
            self.didEncryptText(cipherText!)
        }
    }
    
    fileprivate func didEncryptText(_ cipherText: String) {
        self.cipherTextView.text = cipherText
        enableStep(testDecryptStepView)
    }
    
    @IBAction func copyTextButtonTap(_ sender: AnyObject) {
        if let text = self.cipherTextView.text , text.characters.count > 0 {
            UIPasteboard.general.string = text
            self.showAlert("Copied encrypted text to clipboard")
        }
    }
    
    // MARK: Test Decryption
    
    @IBOutlet weak var cipherTextView: UITextView!
    @IBOutlet weak var plainTextLabel: UILabel!
    
    @IBAction func decryptButtonTap(_ sender: AnyObject) {
        self.view.endEditing(true)
        
        guard let text = self.cipherTextView.text , text.characters.count > 0 else {
            self.showAlert("No text to decrypt")
            return
        }
        
        /// Decrypt the cipher text
        AppDelegate.current.zeroKit?.decrypt(cipherText: text) { plainText, error in
            guard error == nil else {
                self.showAlert("Error decrypting text", message: "\(error!)")
                return
            }
            
            self.didDecryptText(plainText!)
        }
    }
    
    fileprivate func didDecryptText(_ plainText: String) {
        self.plainTextLabel.text = plainText
        enableStep(shareTresorStepView)
    }
    
    // MARK: Step 3: Share
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var shareResultLabel: UILabel!
    
    @IBAction func shareButtonTap(_ sender: AnyObject) {
        self.view.endEditing(true)
        
        guard let username = self.usernameTextField.text, username.characters.count > 0 else {
            self.showAlert("Username cannot be empty")
            return
        }
        
        self.shareResultLabel.text = nil
        
        AppDelegate.current.showProgress()
        
        /// 1. Get the user ID for the specified username.
        AppDelegate.current.backend?.getUserId(forUsername: username) { userId, error in
            guard let userId = userId, error == nil else {
                AppDelegate.current.hideProgress()
                self.showAlert("Error fetching user ID for username", message: "\(error!)")
                return
            }
            
            /// 2. Share the selected tresor with the specified user ID
            AppDelegate.current.zeroKit?.share(tresorWithId: self.tresorId, withUser: userId) { operationId, error in
                guard error == nil else {
                    AppDelegate.current.hideProgress()
                    self.showAlert("Error sharing tresor", message: "\(error!)")
                    return
                }
                
                /// 3. Tresor sharing must be approved via the administrative API. You should send the operation ID to your application backend to handle approval.
                AppDelegate.current.backend?.sharedTresor(operationId: operationId!) { error in
                    AppDelegate.current.hideProgress()
                    if error == nil {
                        self.shareResultLabel.text = "Shared"
                    } else {
                        self.showAlert("Error approving tresor share")
                    }
                }
            }
        }
    }
}
