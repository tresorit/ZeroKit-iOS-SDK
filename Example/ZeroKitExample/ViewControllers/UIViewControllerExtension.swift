import UIKit

extension UIViewController {
    func showAlert(_ title: String?, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel) { (action) in
        })
        self.present(alert, animated: true, completion: nil)
    }
}
