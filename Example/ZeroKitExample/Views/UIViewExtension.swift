import UIKit

extension UIView {
    func setBorderWithColor(_ color: UIColor) {
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = 1 / UIScreen.main.scale
        self.layer.cornerRadius = 5
    }
}
