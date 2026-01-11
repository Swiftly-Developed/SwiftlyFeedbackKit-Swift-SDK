import Foundation

/// Unified secure storage interface with environment-aware key scoping.
///
/// All persistent app data flows through this manager, which stores values
/// in the Keychain with automatic environment prefixing.
///
/// ## Usage
///
/// ```swift
/// // Get the current environment's auth token
/// let token = SecureStorageManager.shared.get(.authToken) as String?
///
/// // Save onboarding completion for current environment
/// SecureStorageManager.shared.set(true, for: .hasCompletedOnboarding)
///
/// // Clear all data for a specific environment
/// SecureStorageManager.shared.clearEnvironment(.development)
/// ```
@MainActor
@Observable
final class SecureStorageManager {
    static let shared = SecureStorageManager()

    /// The current environment used for scoping keys.
    /// Updated automatically when AppConfiguration.environment changes.
    private(set) var currentEnvironment: AppEnvironment

    private init() {
        // Read environment directly from Keychain (bootstrapping)
        if let envData = KeychainManager.get(forKey: "global.selectedEnvironment"),
           let envString = String(data: envData, encoding: .utf8),
           let env = AppEnvironment(rawValue: envString) {
            self.currentEnvironment = env
        } else {
            #if DEBUG
            self.currentEnvironment = .development
            #else
            self.currentEnvironment = BuildEnvironment.isTestFlight ? .testflight : .production
            #endif
        }
    }

    // MARK: - Environment Management

    /// Updates the current environment scope.
    /// Called by AppConfiguration when the environment changes.
    func setEnvironment(_ environment: AppEnvironment) {
        currentEnvironment = environment
        set(environment.rawValue, for: .selectedEnvironment)
    }

    // MARK: - Generic Storage API

    /// Retrieves a value from secure storage.
    /// - Parameter key: The storage key
    /// - Returns: The stored value, or nil if not found
    func get<T>(_ key: StorageKey) -> T? {
        let scopedKey = scopedKey(for: key)

        guard let data = KeychainManager.get(forKey: scopedKey) else {
            return nil
        }

        return decode(data, as: T.self)
    }

    /// Stores a value in secure storage.
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The storage key
    func set<T>(_ value: T?, for key: StorageKey) {
        let scopedKey = scopedKey(for: key)

        guard let value = value else {
            KeychainManager.delete(forKey: scopedKey)
            return
        }

        guard let data = encode(value) else {
            AppLogger.storage.error("Failed to encode value for key: \(key.rawValue)")
            return
        }

        do {
            try KeychainManager.save(data, forKey: scopedKey)
        } catch {
            AppLogger.storage.error("Failed to save to keychain: \(error.localizedDescription)")
        }
    }

    /// Removes a value from secure storage.
    /// - Parameter key: The storage key to remove
    func remove(_ key: StorageKey) {
        let scopedKey = scopedKey(for: key)
        KeychainManager.delete(forKey: scopedKey)
    }

    /// Checks if a value exists in secure storage.
    /// - Parameter key: The storage key
    /// - Returns: true if a value exists
    func exists(_ key: StorageKey) -> Bool {
        let scopedKey = scopedKey(for: key)
        return KeychainManager.get(forKey: scopedKey) != nil
    }

    // MARK: - Bulk Operations

    /// Clears all data for a specific environment.
    /// - Parameter environment: The environment to clear
    func clearEnvironment(_ environment: AppEnvironment) {
        KeychainManager.deleteAll(withScopePrefix: environment.rawValue)
        AppLogger.storage.info("Cleared all data for environment: \(environment.rawValue)")
    }

    /// Clears all debug settings.
    func clearDebugSettings() {
        KeychainManager.deleteAll(withScopePrefix: "debug")
        AppLogger.storage.info("Cleared all debug settings")
    }

    /// Clears ALL stored data (use with caution).
    func clearAll() {
        KeychainManager.deleteAllItems()
        AppLogger.storage.warning("Cleared ALL keychain data")
    }

    /// Lists all stored keys (for debugging).
    func listAllKeys() -> [String] {
        KeychainManager.listAllKeys()
    }

    // MARK: - Private Helpers

    /// Generates the scoped key for storage.
    private func scopedKey(for key: StorageKey) -> String {
        if let fixedScope = key.fixedScope {
            return "\(fixedScope).\(key.rawValue)"
        } else if key.isEnvironmentScoped {
            return "\(currentEnvironment.rawValue).\(key.rawValue)"
        } else {
            // Fallback (shouldn't happen with proper key configuration)
            return "global.\(key.rawValue)"
        }
    }

    /// Encodes a value to Data for Keychain storage.
    private func encode<T>(_ value: T) -> Data? {
        switch value {
        case let string as String:
            return string.data(using: .utf8)
        case let bool as Bool:
            return Data([bool ? 1 : 0])
        case let int as Int:
            return withUnsafeBytes(of: int) { Data($0) }
        case let codable as any Codable:
            return try? JSONEncoder().encode(AnyEncodable(codable))
        default:
            return nil
        }
    }

    /// Decodes Data from Keychain to the requested type.
    private func decode<T>(_ data: Data, as type: T.Type) -> T? {
        if type == String.self {
            return String(data: data, encoding: .utf8) as? T
        } else if type == Bool.self {
            return (data.first == 1) as? T
        } else if type == Int.self {
            guard data.count >= MemoryLayout<Int>.size else { return nil }
            return data.withUnsafeBytes { $0.load(as: Int.self) } as? T
        } else if let decodableType = type as? any Decodable.Type {
            return try? JSONDecoder().decode(AnyDecodable<T>.self, from: data).value
        }
        return nil
    }
}

// MARK: - Codable Helpers

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

private struct AnyDecodable<T>: Decodable {
    let value: T

    init(from decoder: Decoder) throws {
        guard let decodableType = T.self as? any Decodable.Type else {
            throw DecodingError.typeMismatch(T.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Type does not conform to Decodable"
            ))
        }
        let decodedValue = try decodableType.init(from: decoder)
        guard let typedValue = decodedValue as? T else {
            throw DecodingError.typeMismatch(T.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Decoded value could not be cast to expected type"
            ))
        }
        self.value = typedValue
    }
}

// MARK: - Convenience Extensions

extension SecureStorageManager {
    /// Convenience getter for auth token.
    var authToken: String? {
        get { get(.authToken) }
        set { set(newValue, for: .authToken) }
    }

    /// Convenience getter for onboarding completion.
    var hasCompletedOnboarding: Bool {
        get { get(.hasCompletedOnboarding) ?? false }
        set { set(newValue, for: .hasCompletedOnboarding) }
    }

    /// Whether to keep the user signed in (save credentials for auto re-login).
    var keepMeSignedIn: Bool {
        get { get(.keepMeSignedIn) ?? false }
        set { set(newValue, for: .keepMeSignedIn) }
    }

    /// Saved email for auto re-login.
    var savedEmail: String? {
        get { get(.savedEmail) }
        set { set(newValue, for: .savedEmail) }
    }

    /// Saved password for auto re-login.
    var savedPassword: String? {
        get { get(.savedPassword) }
        set { set(newValue, for: .savedPassword) }
    }

    /// Saves credentials for auto re-login if keepMeSignedIn is enabled.
    func saveCredentialsIfEnabled(email: String, password: String) {
        if keepMeSignedIn {
            savedEmail = email
            savedPassword = password
            AppLogger.storage.info("Credentials saved for auto re-login")
        }
    }

    /// Clears saved credentials.
    func clearSavedCredentials() {
        savedEmail = nil
        savedPassword = nil
        AppLogger.storage.info("Saved credentials cleared")
    }

    /// Returns saved credentials if available.
    func getSavedCredentials() -> (email: String, password: String)? {
        guard keepMeSignedIn,
              let email = savedEmail,
              let password = savedPassword else {
            return nil
        }
        return (email, password)
    }
}
