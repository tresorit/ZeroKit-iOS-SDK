import Foundation

protocol ApiJs {
    var sourceUrl: URL { get }
    func javascript() throws -> String
}

struct ApiJsUrl: ApiJs {
    let sourceUrl: URL
    let shouldLoad: Bool
    init(sourceUrl: URL, shouldLoad: Bool = true) {
        self.sourceUrl = sourceUrl
        self.shouldLoad = shouldLoad
    }
    func javascript() throws -> String {
        if shouldLoad {
            return try String(contentsOf: sourceUrl)
        }
        return ""
    }
}
