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
        do {
            let container = CKContainer.default()
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

    /// Clears the stored user ID from Keychain.
    /// Useful for testing or when the user wants to reset their identity.
    public static func clearUserId() {
        KeychainHelper.delete(.userId)
    }
}
