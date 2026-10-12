import Foundation
import os
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
/// Where a user id is remembered. Production uses the Keychain. Tests install a memory store
/// so they do not write the host's real FeedbackKit keychain item.
protocol UserIDStoring: Sendable {
    func get() -> String?
    @discardableResult
    func save(_ value: String) -> Bool
    @discardableResult
    func delete() -> Bool
}

struct KeychainUserIDStore: UserIDStoring {
    func get() -> String? { KeychainHelper.get(.userId) }

    func save(_ value: String) -> Bool { KeychainHelper.save(value, for: .userId) }

    func delete() -> Bool { KeychainHelper.delete(.userId) }
}

public enum UserIdentifier {
    /// How long configuration will wait for an iCloud record name before minting a local id.
    ///
    /// `userRecordID()` has no timeout of its own. Offline, with a CloudKit entitlement, that
    /// call can hold `configure` open so `current` stays nil and every view has no client.
    static let iCloudLookupTimeout: Duration = .seconds(3)

    private static let storage = OSAllocatedUnfairLock<any UserIDStoring>(initialState: KeychainUserIDStore())

    /// Installs `store` and returns the previous one. The caller restores it.
    static func swapStoreForTesting(_ store: any UserIDStoring) -> any UserIDStoring {
        storage.withLock { current in
            let previous = current
            current = store
            return previous
        }
    }

    private static func store() -> any UserIDStoring {
        storage.withLock { $0 }
    }

    /// Gets or generates a persistent user identifier.
    /// The ID is stored securely in the Keychain.
    ///
    /// - Parameter customId: Optional custom ID to use instead of auto-generated ID
    /// - Returns: A persistent user identifier string
    public static func getOrCreateUserId(customId: String? = nil) async -> String {
        let activeStore = store()
        return await resolveUserId(
            customId: customId,
            readStored: { activeStore.get() },
            writeStored: { value in
                _ = activeStore.save(value)
            },
            icloud: { await fetchICloudUserId() },
            generate: { "local_\(UUID().uuidString)" }
        )
    }

    /// The id to use, in the documented order, without touching CloudKit or the Keychain itself.
    ///
    /// After the iCloud lookup returns, the stored id is read again. A custom id saved while
    /// that lookup was in flight wins. The lookup must not overwrite it.
    static func resolveUserId(
        customId: String?,
        readStored: @Sendable () -> String?,
        writeStored: @escaping @Sendable (String) -> Void,
        icloud: @escaping @Sendable () async -> String?,
        generate: @escaping @Sendable () -> String
    ) async -> String {
        let trimmedCustom = customId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedCustom, !trimmedCustom.isEmpty {
            writeStored(trimmedCustom)
            return trimmedCustom
        }

        if let existing = present(readStored()) {
            return existing
        }

        if let icloudId = await icloud() {
            if let existing = present(readStored()) {
                return existing
            }
            let trimmedRecord = icloudId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedRecord.isEmpty {
                let userId = "icloud_\(trimmedRecord)"
                writeStored(userId)
                return userId
            }
        }

        if let existing = present(readStored()) {
            return existing
        }

        let generated = generate()
        writeStored(generated)
        return generated
    }

    private static func present(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    /// First result of `operation`, or nil when `timeout` elapses first.
    static func firstCompleted(
        _ operation: @escaping @Sendable () async -> String?,
        timeout: Duration
    ) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Gets the current user ID from Keychain without generating a new one.
    public static func getCurrentUserId() -> String? {
        store().get()
    }

    /// Updates the stored user ID with a custom value.
    @discardableResult
    public static func setCustomUserId(_ customId: String) -> Bool {
        store().save(customId)
    }

    /// Attempts to fetch the iCloud user record ID.
    /// This ID is consistent across all devices signed into the same iCloud account.
    ///
    /// Gives up after ``iCloudLookupTimeout`` so an offline CloudKit lookup cannot hold
    /// configuration open.
    private static func fetchICloudUserId() async -> String? {
        await firstCompleted(fetchICloudUserRecord, timeout: iCloudLookupTimeout)
    }

    private static func fetchICloudUserRecord() async -> String? {
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
        store().delete()
    }
}
