//
//  BuildEnvironment.swift
//  SwiftlyFeedbackKit
//
//  Detects the current build environment (Debug, TestFlight, App Store)
//

import Foundation
import StoreKit

#if os(macOS)
import Security
#endif

enum BuildEnvironment {
    /// Cached environment detection result (computed once at startup)
    private static let cachedEnvironment: AppStore.Environment? = {
        // Use synchronous approach with Task for initial detection
        // This is safe because it's only called once during static initialization
        let semaphore = DispatchSemaphore(value: 0)
        var result: AppStore.Environment?

        Task {
            do {
                let verification = try await AppTransaction.shared
                if case .verified(let transaction) = verification {
                    result = transaction.environment
                }
            } catch {
                // Fall back to nil if AppTransaction fails
            }
            semaphore.signal()
        }

        // Wait with a short timeout to avoid blocking indefinitely
        _ = semaphore.wait(timeout: .now() + 1.0)
        return result
    }()

    /// Debug override to simulate TestFlight (for local testing)
    /// Set this to true in Debug Settings to test TestFlight behavior
    static var simulateTestFlight: Bool {
        get {
            #if DEBUG
            return UserDefaults.standard.bool(forKey: "debug.simulateTestFlight")
            #else
            return false
            #endif
        }
        set {
            #if DEBUG
            UserDefaults.standard.set(newValue, forKey: "debug.simulateTestFlight")
            #endif
        }
    }

    /// Check if the app is running in DEBUG mode (Xcode development)
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Check if the app is running from TestFlight
    static var isTestFlight: Bool {
        #if DEBUG
        // In DEBUG mode, check if we're simulating TestFlight
        return simulateTestFlight
        #else
        // Use StoreKit AppTransaction environment (modern API)
        if let environment = cachedEnvironment {
            return environment == .sandbox
        }

        // Fallback: Use platform-specific detection
        #if os(macOS)
        return detectTestFlightMacOS()
        #else
        return false
        #endif
        #endif
    }

    /// Check if the app is running from App Store (production)
    static var isAppStore: Bool {
        #if DEBUG
        return false
        #else
        // Use StoreKit AppTransaction environment (modern API)
        if let environment = cachedEnvironment {
            return environment == .production
        }
        return false
        #endif
    }

    /// Check if we should show internal testing features
    static var canShowTestingFeatures: Bool {
        return isDebug || isTestFlight
    }

    /// Get a human-readable build environment string
    static var displayName: String {
        if isDebug {
            return "Debug (Xcode)"
        } else if isTestFlight {
            return "TestFlight"
        } else if isAppStore {
            return "App Store"
        } else {
            return "Unknown"
        }
    }

    #if os(macOS)
    /// macOS fallback: Check code signing certificate for TestFlight marker OID
    private static func detectTestFlightMacOS() -> Bool {
        var code: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(
            Bundle.main.bundleURL as CFURL,
            [],
            &code
        )

        guard status == noErr, let code = code else {
            return false
        }

        var requirement: SecRequirement?
        let requirementStatus = SecRequirementCreateWithString(
            "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.25.1]" as CFString,
            [],
            &requirement
        )

        guard requirementStatus == noErr, let requirement = requirement else {
            return false
        }

        return SecStaticCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
    #endif
}
