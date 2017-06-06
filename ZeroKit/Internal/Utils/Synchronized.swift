import Foundation

extension NSObjectProtocol {
    static func zk_synchronized(_ closure: (Void) -> Void) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        closure()
    }
    
    func zk_synchronized(_ closure: (Void) -> Void) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        closure()
    }
}
