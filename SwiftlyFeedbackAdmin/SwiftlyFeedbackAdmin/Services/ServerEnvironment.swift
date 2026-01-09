import Foundation

enum ServerEnvironment: String, CaseIterable, Identifiable {
    case localhost = "localhost"
    case dev = "development"
    case staging = "staging"
    case production = "production"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .localhost: return "Localhost"
        case .dev: return "Development"
        case .staging: return "Staging"
        case .production: return "Production"
        }
    }

    var baseURL: URL {
        switch self {
        case .localhost:
            return URL(string: "http://localhost:8080/api/v1")!
        case .dev:
            return URL(string: "https://feedbackkit-dev-3d08c4624108.herokuapp.com/api/v1")!
        case .staging:
            return URL(string: "https://feedbackkit-testflight-2e08ccf13bc4.herokuapp.com/api/v1")!
        case .production:
            return URL(string: "https://feedbackkit-production-cbea7fa4b19d.herokuapp.com/api/v1")!
        }
    }

    var color: String {
        switch self {
        case .localhost: return "gray"
        case .dev: return "blue"
        case .staging: return "orange"
        case .production: return "red"
        }
    }

    // UserDefaults key
    private static let storageKey = "com.swiftlyfeedback.admin.serverEnvironment"

    static var current: ServerEnvironment {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
                  let environment = ServerEnvironment(rawValue: rawValue) else {
                return .localhost // Default to localhost
            }
            return environment
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}
