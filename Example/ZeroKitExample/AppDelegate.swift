import UIKit
import ZeroKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var zeroKit: ZeroKit?
    var mockApp: ExampleAppMock?
    
    static var current: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.tintColor = UIColor(red: 3/255.0, green: 173/255.0, blue: 211/255.0, alpha: 1.0)
        window?.rootViewController = UIViewController()
        window?.rootViewController!.view.backgroundColor = UIColor.white
        window?.makeKeyAndVisible()
        
        mockApp = ExampleAppMock()
        
        let apiBaseUrl = URL(string: Bundle.main.infoDictionary!["ZeroKitAPIBaseURL"] as! String)!
        let zeroKitConfig = ZeroKitConfig(apiBaseUrl: apiBaseUrl)
        zeroKit = try! ZeroKit(config: zeroKitConfig)
        
        showSigninScreen()
        
        return true
    }
    
    func showSigninScreen() {
        window?.rootViewController = notSignedInViewController()
    }
    
    func showAfterSigninScreen() {
        window?.rootViewController = signedInViewController()
    }
    
    fileprivate func notSignedInViewController() -> UIViewController {
        let mainSb = UIStoryboard(name: "Main", bundle: nil)
        let tabs = UITabBarController()
        tabs.viewControllers = [mainSb.instantiateViewController(withIdentifier: "SignInViewController"),
                                mainSb.instantiateViewController(withIdentifier: "SignUpViewController")]
        return tabs
    }
    
    fileprivate func signedInViewController() -> UIViewController {
        let mainSb = UIStoryboard(name: "Main", bundle: nil)
        let tabs = UITabBarController()
        tabs.viewControllers = [mainSb.instantiateViewController(withIdentifier: "EncryptViewController"),
                                mainSb.instantiateViewController(withIdentifier: "DecryptViewController"),
                                mainSb.instantiateViewController(withIdentifier: "AccountViewController")]
        return tabs
    }
    
    fileprivate var progressView: UIView?
    
    func showProgress() {
        if progressView != nil {
            return
        }
        
        let view = UIView(frame: self.window!.bounds)
        view.backgroundColor = UIColor(white: 0, alpha: 0.65)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.translatesAutoresizingMaskIntoConstraints = true
        
        let activity = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        activity.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        activity.startAnimating()
        view.addSubview(activity)
        
        self.window?.addSubview(view)
        self.progressView = view
    }
    
    func hideProgress() {
        progressView?.removeFromSuperview()
        progressView = nil
    }
}

