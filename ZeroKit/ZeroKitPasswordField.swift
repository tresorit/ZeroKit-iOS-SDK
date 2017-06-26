import UIKit

/**
 Implement the `ZeroKitPasswordFieldDelegate` protocol to get notified of password field events.
 */
@objc public protocol ZeroKitPasswordFieldDelegate: class, NSObjectProtocol {
    /**
     Called when the contents of the password field changes.
     */
    @objc optional func passwordFieldContentsChanged(_ passwordField: ZeroKitPasswordField)
    
    /**
     Called when the Return key was pressed.
     */
    @objc optional func passwordFieldReturnWasPressed(_ passwordField: ZeroKitPasswordField)
    
    /**
     Return `false` to disallow editing.
     */
    @objc optional func passwordFieldShouldBeginEditing(_ passwordField: ZeroKitPasswordField) -> Bool
    
    /**
     The password field became first responder.
     */
    @objc optional func passwordFieldDidBeginEditing(_ passwordField: ZeroKitPasswordField)
    
    /**
     Return `true` to allow editing to stop and to resign first responder status. `False` to disallow the editing session to end.
     */
    @objc optional func passwordFieldShouldEndEditing(_ passwordField: ZeroKitPasswordField) -> Bool
    
    /**
     May be called if forced even if shouldEndEditing returns `false` (e.g. view removed from window) or `endEditing(true)` called.
     */
    @objc optional func passwordFieldDidEndEditing(_ passwordField: ZeroKitPasswordField)
}


/**
 The ZeroKitPasswordField provides the ZeroKit SDK user with a text field that hides access to the user's password.
 Making it harder to make mistakes when handling the password.
 
 You can customize some appearance properties in interface builder. Customize the rest in code.
 */
@IBDesignable
public class ZeroKitPasswordField: UIView {

    fileprivate var textField: UITextField!
    
    /**
     When the user needs to enter the password twice for confirmation, use this property to match two password fields. When password fields are matched you can use the `passwordsMatch` property to check if the contents of the two fields are the same.
     
     Setting the `matchingField` on one will also set it on the other password field.
     
     - note: The password fields hold weak references to each other.
     */
    public weak var matchingField: ZeroKitPasswordField? {
        get {
            return _matchingField
        }
        set {
            _matchingField?._matchingField = nil
            _matchingField = newValue
            newValue?._matchingField = self
        }
    }
    
    private weak var _matchingField: ZeroKitPasswordField?
    
    public weak var delegate: ZeroKitPasswordFieldDelegate?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupTextField()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupTextField()
    }
    
    private func setupTextField() {
        textField = UITextField(frame: self.bounds)
        textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textField.translatesAutoresizingMaskIntoConstraints = true
        textField.isSecureTextEntry = true
        textField.borderStyle = .roundedRect
        textField.font = UIFont.systemFont(ofSize: 14)
        
        textFieldDelegate = PasswordTextFieldDelegate(passwordField: self)
        
        addSubview(textField)
        backgroundColor = UIColor.clear
        isOpaque = false
    }
    
    /**
     `true` if the field is empty
     */
    public var isEmpty: Bool {
        return self.password.characters.count == 0
    }
    
    /**
     Get the length of the typed password.
     */
    public var passwordLength: Int {
        return self.password.characters.count
    }
    
    /**
     `true` if the entered password is valid
     
     **Deprecated.** Use the `passwordStrength` method on a `ZeroKit` object to get the password strength.
     
     - note: ZeroKit does not specify requirements for passwords, so technically any password that is at least 1 character long is valid. Use the password strength to enforce requirements for your app.
     */
    @available(*, deprecated: 4.0.3, message: "Use the `passwordStrength` method on a `ZeroKit` object to get the password strength.")
    public func isPasswordValid() -> Bool {
        return self.password.characters.count > 0
    }
    
    /**
     Check if this field and its `matchingField` has the same content. Value if false if the password field's `matchingField` property is nil.
     */
    public var passwordsMatch: Bool {
        guard let other = self.matchingField else {
            return false
        }
        
        return self.password == other.password
    }
    
    /**
     Clear the password field.
     */
    public func clear() {
        self.textField.text = ""
    }
    
    // MARK: Layout
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        return textField.sizeThatFits(size)
    }
    
    public override var intrinsicContentSize: CGSize {
        return textField.intrinsicContentSize
    }
    
    
    // MARK: Text field delegate
    
    private var textFieldDelegate: PasswordTextFieldDelegate!
    
    private class PasswordTextFieldDelegate: NSObject, UITextFieldDelegate {
        private weak var parent: ZeroKitPasswordField?
        
        init(passwordField: ZeroKitPasswordField) {
            super.init()
            parent = passwordField
            parent!.textField.delegate = self
            parent!.textField.addTarget(self, action: #selector(textFieldEditingChanged(_:)), for: .editingChanged)
        }
        
        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            if let p = parent, let value = p.delegate?.passwordFieldShouldBeginEditing?(p) {
                return value
            } else {
                return true
            }
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            if let p = parent {
                p.delegate?.passwordFieldDidBeginEditing?(p)
            }
        }
        
        func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
            if let p = parent, let value = p.delegate?.passwordFieldShouldEndEditing?(p) {
                return value
            } else {
                return true
            }
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            if let p = parent {
                p.delegate?.passwordFieldDidEndEditing?(p)
            }
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            return true
        }
        
        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            return true
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let p = parent {
                p.delegate?.passwordFieldReturnWasPressed?(p)
            }
            return true
        }
        
        func textFieldEditingChanged(_ textField: UITextField) {
            if let p = parent {
                p.delegate?.passwordFieldContentsChanged?(p)
            }
        }
    }

    
    // MARK: Text field properties
    
    @IBInspectable public var attributedPlaceholder: NSAttributedString? {
        get { return textField.attributedPlaceholder }
        set { textField.attributedPlaceholder = newValue }
    }
    
    @IBInspectable public var placeholder: String? {
        get { return textField.placeholder }
        set { textField.placeholder = newValue }
    }
    
    @IBInspectable public var font: UIFont? {
        get { return textField.font }
        set { textField.font = newValue }
    }
    
    @IBInspectable public var textColor: UIColor? {
        get { return textField.textColor }
        set { textField.textColor = newValue }
    }
    
    @IBInspectable public var textAlignment: NSTextAlignment {
        get { return textField.textAlignment }
        set { textField.textAlignment = newValue }
    }
    
    public var isEditing: Bool {
        return textField.isEditing
    }
    
    @IBInspectable public var isEnabled: Bool {
        get { return textField.isEnabled }
        set { textField.isEnabled = newValue }
    }
    
    @IBInspectable public var background: UIImage? {
        get { return textField.background }
        set { textField.background = newValue }
    }
    
    @IBInspectable public var disabledBackground: UIImage? {
        get { return textField.disabledBackground }
        set { textField.disabledBackground = newValue }
    }
    
    @IBInspectable public var borderStyle: UITextBorderStyle {
        get { return textField.borderStyle }
        set { textField.borderStyle = newValue }
    }
    
    @IBInspectable public var keyboardAppearance: UIKeyboardAppearance {
        get { return textField.keyboardAppearance }
        set { textField.keyboardAppearance = newValue }
    }
    
    @IBInspectable public var returnKeyType: UIReturnKeyType {
        get { return textField.returnKeyType }
        set { textField.returnKeyType = newValue }
    }
}

// MARK: ZeroKit internal
extension ZeroKitPasswordField {
    var password: String {
        return textField.text ?? ""
    }
}
