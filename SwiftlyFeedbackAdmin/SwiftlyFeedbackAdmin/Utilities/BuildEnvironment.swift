//
//  BuildEnvironment.swift
//  SwiftlyFeedbackAdmin
//
//  Detects the current build environment (Debug, TestFlight, App Store)
//
//  Setup for compile-time TESTFLIGHT detection:
//  1. In Xcode, go to Project Settings > Build Settings
//  2. Search for "Active Compilation Conditions"
//  3. For your TestFlight/Beta build configuration, add: TESTFLIGHT
//
//  This allows using #if TESTFLIGHT in code for compile-time checks.
//  Runtime detection is used as a fallback when the flag isn't set.
//

import Foundation

#if os(macOS)
import Security
#endif

// MARK: - Distribution Type

/// Represents the distribution channel for the app
enum Distribution: String, Sendable {
    case debug = "Debug"
    case testflight = "TestFlight"
    case appStore = "App Store"

    /// The current distribution based on compile-time flags and runtime detection
    static var current: Distribution {
        // 1. Compile-time detection (most reliable when configured)
        #if DEBUG
        // In DEBUG, check for TestFlight simulation
        return BuildEnvironment.simulateTestFlight ? .testflight : .debug
        #elseif TESTFLIGHT
        return .testflight
        #else
        // 2. Runtime detection fallback for Release builds without TESTFLIGHT flag
        if RuntimeEnvironment.isTestFlight {
            return .testflight
        } else {
            return .appStore
        }
        #endif
    }
}

// MARK: - Build Environment (Legacy API + New Features)

/// Detects and provides information about the current build environment
enum BuildEnvironment {

    // MARK: - Simulation (Debug Only)

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

    // MARK: - Build Type Detection

    /// Check if the app is running in DEBUG mode (Xcode development)
    static var isDebug: Bool {
        #if DEBUG
        return !simulateTestFlight
        #else
        return false
        #endif
    }

    /// Check if the app is running from TestFlight
    /// Uses compile-time flag if available, falls back to runtime detection
    static var isTestFlight: Bool {
        #if DEBUG
        // In DEBUG mode, check if we're simulating TestFlight
        return simulateTestFlight
        #elseif TESTFLIGHT
        // Compile-time flag is set - this is a TestFlight build
        return true
        #else
        // Fall back to runtime detection
        return RuntimeEnvironment.isTestFlight
        #endif
    }

    /// Check if the app is running from App Store (production)
    static var isAppStore: Bool {
        #if DEBUG
        return false
        #elseif TESTFLIGHT
        return false
        #else
        return !RuntimeEnvironment.isTestFlight
        #endif
    }

    // MARK: - Feature Flags

    /// Check if we should show internal testing features (Debug or TestFlight)
    static var canShowTestingFeatures: Bool {
        #if DEBUG
        return true
        #elseif TESTFLIGHT
        return true
        #else
        return RuntimeEnvironment.isTestFlight
        #endif
    }

    /// Alias for canShowTestingFeatures - indicates developer mode is available
    static var isDeveloperMode: Bool {
        canShowTestingFeatures
    }

    // MARK: - Display

    /// Get a human-readable build environment string
    static var displayName: String {
        Distribution.current.rawValue
    }

    /// Get the current distribution type
    static var distribution: Distribution {
        Distribution.current
    }
}

// MARK: - Runtime Environment Detection

/// Runtime detection methods for build environment
/// Used as fallback when compile-time flags aren't available
private enum RuntimeEnvironment {

    /// Detect TestFlight at runtime using platform-specific methods
    static var isTestFlight: Bool {
        #if os(macOS)
        return detectTestFlightMacOS()
        #else
        return detectTestFlightIOS()
        #endif
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    /// iOS/tvOS/visionOS: Check for TestFlight receipt
    private static func detectTestFlightIOS() -> Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        // TestFlight apps have receipts at "sandboxReceipt"
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }
    #endif

    #if os(macOS)
    /// macOS: Check code signing certificate for TestFlight marker OID
    /// The marker OID 1.2.840.113635.100.6.1.25.1 is specific to TestFlight distribution
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
        // Check for TestFlight distribution certificate marker OID
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

// MARK: - Conditional Compilation Helpers

/// Extension providing compile-time conditional values
/// Uses Swift's expression-based conditional compilation
extension BuildEnvironment {

    /// Returns a value based on the current build environment
    /// - Parameters:
    ///   - debug: Value for Debug builds
    ///   - testflight: Value for TestFlight builds
    ///   - appStore: Value for App Store builds
    /// - Returns: The appropriate value for the current environment
    static func value<T>(
        debug: @autoclosure () -> T,
        testflight: @autoclosure () -> T,
        appStore: @autoclosure () -> T
    ) -> T {
        #if DEBUG
        return simulateTestFlight ? testflight() : debug()
        #elseif TESTFLIGHT
        return testflight()
        #else
        return RuntimeEnvironment.isTestFlight ? testflight() : appStore()
        #endif
    }

    /// Returns a value based on whether testing features are available
    /// - Parameters:
    ///   - testing: Value for Debug/TestFlight builds
    ///   - production: Value for App Store builds
    /// - Returns: The appropriate value
    static func value<T>(
        testing: @autoclosure () -> T,
        production: @autoclosure () -> T
    ) -> T {
        canShowTestingFeatures ? testing() : production()
    }
}
