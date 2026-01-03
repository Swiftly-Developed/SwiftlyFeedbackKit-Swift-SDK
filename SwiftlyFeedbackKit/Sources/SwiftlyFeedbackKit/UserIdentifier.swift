import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

/// Generates and manages persistent user identifiers stored securely in Keychain.
///
/// The user ID is determined in this order of precedence:
/// 1. Custom ID (if set via `SwiftlyFeedback.updateUser(customID:)`)
/// 2. Existing ID from Keychain (persists across app reinstalls)
/// 3. iCloud account identifier (same across devices for the same iCloud user)
/// 4. Newly generated UUID (stored in Keychain)
public enum UserIdentifier {

    /// Gets or generates a persistent user identifier.
    /// The ID is stored securely in the Keychain.
    ///
    /// - Parameter customId: Optional custom ID to use instead of auto-generated ID
    /// - Returns: A persistent user identifier string
    public static func getOrCreateUserId(customId: String? = nil) async -> String {
        // Priority 1: Custom ID
        if let customId = customId, !customId.isEmpty {
            KeychainHelper.save(customId, for: .userId)
            return customId
        }

        // Priority 2: Existing ID from Keychain
        if let existingId = KeychainHelper.get(.userId) {
            return existingId
        }

        // Priority 3: Try to get iCloud user record ID
        if let iCloudId = await fetchICloudUserId() {
            let userId = "icloud_\(iCloudId)"
            KeychainHelper.save(userId, for: .userId)
            return userId
        }

        // Priority 4: Generate and store new UUID
        let newId = "local_\(UUID().uuidString)"
        KeychainHelper.save(newId, for: .userId)
        return newId
    }

    /// Gets the current user ID from Keychain without generating a new one.
    public static func getCurrentUserId() -> String? {
        KeychainHelper.get(.userId)
    }

    /// Updates the stored user ID with a custom value.
    @discardableResult
    public static func setCustomUserId(_ customId: String) -> Bool {
        KeychainHelper.save(customId, for: .userId)
    }

    /// Attempts to fetch the iCloud user record ID.
    /// This ID is consistent across all devices signed into the same iCloud account.
    private static func fetchICloudUserId() async -> String? {
        #if canImport(CloudKit)
        // Check if CloudKit container is available
        // CKContainer.default() throws an uncatchable ObjC exception if entitlements are missing
        guard let containerIdentifier = cloudKitContainerIdentifier() else {
            return nil
        }

        do {
            // Use explicit container identifier to avoid CKContainer.default() crash
            let container = CKContainer(identifier: containerIdentifier)
            let recordID = try await container.userRecordID()
            return recordID.recordName
        } catch {
            // iCloud not available or user not signed in
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Checks if CloudKit is properly configured for this app.
    /// Returns the container identifier if available, nil otherwise.
    private static func cloudKitContainerIdentifier() -> String? {
        #if canImport(CloudKit)
        // Check for explicit iCloud container identifiers in entitlements
        // These are only present when the app has the iCloud capability properly configured

        // First check if there's a custom container identifier
        if let containers = Bundle.main.object(forInfoDictionaryKey: "CKContainerIdentifiers") as? [String],
           let firstContainer = containers.first {
            return firstContainer
        }

        // Check for iCloud containers entitlement (set by Xcode when capability is added)
        if let containers = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.icloud-container-identifiers") as? [String],
           let firstContainer = containers.first {
            return firstContainer
        }

        // Without explicit container identifiers in the app's configuration,
        // we cannot safely use CloudKit as it requires:
        // 1. com.apple.developer.icloud-services entitlement with "CloudKit"
        // 2. Proper code signing with a team ID
        //
        // Attempting to use CKContainer without these will crash the app.
        // Return nil to fall back to local UUID generation.
        return nil
        #else
        return nil
        #endif
    }

    /// Clears the stored user ID from Keychain.
    /// Useful for testing or when the user wants to reset their identity.
    public static func clearUserId() {
        KeychainHelper.delete(.userId)
    }
}
