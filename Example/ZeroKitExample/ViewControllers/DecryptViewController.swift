import UIKit

class DecryptViewController: UIViewController {

    @IBOutlet weak var cipherTextView: UITextView!
    @IBOutlet weak var plainTextLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.plainTextLabel.text = nil
        
        let textInputBorderColor = UIColor.lightGray
        self.cipherTextView.setBorderWithColor(textInputBorderColor)
    }
    
    @IBAction func decryptButtonTap(_ sender: AnyObject) {
        guard let text = self.cipherTextView.text , text.characters.count > 0 else {
            self.showAlert("Enter text to decrypt")
            return
        }
        
        self.plainTextLabel.text = nil
        
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
    }
    
    @IBAction func pasteButtonTap(_ sender: AnyObject) {
        guard let text = UIPasteboard.general.string else {
            self.showAlert("No string on clipboard to paste")
            return
        }
        
        self.cipherTextView.text = text
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }
}
