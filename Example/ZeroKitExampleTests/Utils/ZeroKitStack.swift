import ZeroKit

public class ZeroKitStack: NSObject {
    public let zeroKit: ZeroKit
    public let backend: Backend
    
    public init(zeroKit: ZeroKit, backend: Backend) {
        self.zeroKit = zeroKit
        self.backend = backend
    }
}
