//
//  BuildEnvironment.swift
//  SwiftlyFeedbackKit
//
//  Detects the current build environment (Debug, TestFlight, App Store)
//

import Foundation

#if os(macOS)
import Security
#endif

enum BuildEnvironment {
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
        #if os(macOS)
        // macOS-specific: Check code signing certificate for TestFlight marker
        var status = noErr
        var code: SecStaticCode?

        status = SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code)
        guard status == noErr, let code = code else { return false }

        var requirement: SecRequirement?
        // Check for TestFlight distribution certificate marker OID
        status = SecRequirementCreateWithString(
            "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.25.1]" as CFString,
            [],
            &requirement
        )
        guard status == noErr, let requirement = requirement else { return false }

        status = SecStaticCodeCheckValidity(code, [], requirement)
        return status == errSecSuccess
        #else
        // iOS/tvOS/visionOS: Check for TestFlight receipt
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }

        // TestFlight apps have receipts at "sandboxReceipt"
        return receiptURL.lastPathComponent == "sandboxReceipt"
        #endif
        #endif
    }

    /// Check if the app is running from App Store (production)
    static var isAppStore: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }

        // App Store apps have receipts at "receipt"
        return receiptURL.lastPathComponent == "receipt" && !isDebug
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
}
