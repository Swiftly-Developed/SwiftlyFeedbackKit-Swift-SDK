import Testing
import Foundation
@testable import SwiftlyFeedbackKit

/// Per-environment **credential selection** for the Swift SDK — the SDK-side twin of the Admin's
/// environment-scoped Keychain key (`QA-UNIT03-AUTH` §4.1, §23.1 correction 3).
///
/// ⚠️ **Four of these cases are wholly `#if DEBUG`.** Under `swift test` DEBUG is defined and they
/// run, but a compiled-out body is an EMPTY body, and an empty `@Test` reports as a pass — a gate
/// whose OFF branch is indistinguishable from success (`TESTING.md` §14.3). Each now carries an
/// `#else` that records an issue, so a configuration in which they are inert reads as red rather
/// than as four more greens.
///
/// **Stated limitation:** the TestFlight and App Store arms of `currentKey` / `currentServerURL`
/// are unreachable from this target — they are selected by a compilation condition plus
/// `BuildEnvironment.isTestFlight`, and no unit test can enter them. What is covered is the DEBUG
/// arm and the invariant that it never hands back the production credential.
@Suite("EnvironmentAPIKeys")
struct EnvironmentAPIKeysTests {

    @Test("Initialization with all keys")
    func initWithAllKeys() {
        let keys = EnvironmentAPIKeys(
            debug: "debug_key",
            testflight: "tf_key",
            production: "prod_key"
        )

        #expect(keys.debug == "debug_key")
        #expect(keys.testflight == "tf_key")
        #expect(keys.production == "prod_key")
    }

    @Test("Initialization without debug key")
    func initWithoutDebugKey() {
        let keys = EnvironmentAPIKeys(
            testflight: "tf_key",
            production: "prod_key"
        )

        #expect(keys.debug == nil)
        #expect(keys.testflight == "tf_key")
        #expect(keys.production == "prod_key")
    }

    @Test("Current key selection in DEBUG with debug key")
    func currentKeyInDebugWithDebugKey() {
        #if DEBUG
        let keys = EnvironmentAPIKeys(
            debug: "debug_key",
            testflight: "tf_key",
            production: "prod_key"
        )
        #expect(keys.currentKey == "debug_key")

        // The claim that makes this per-environment SELECTION rather than a lookup: a debug
        // build must never hand back the production credential.
        #expect(keys.currentKey != keys.production)
        #expect(keys.currentKey != keys.testflight)
        #else
        Issue.record("Compiled without DEBUG: this case's body is empty and its green is vacuous.")
        #endif
    }

    @Test("Current key selection in DEBUG without debug key")
    func currentKeyInDebugWithoutDebugKey() {
        #if DEBUG
        let keys = EnvironmentAPIKeys(
            testflight: "tf_key",
            production: "prod_key"
        )
        // Falls back to testflight key when no debug key provided
        #expect(keys.currentKey == "tf_key")
        #expect(keys.currentKey != keys.production, "a debug build must not select the production key")
        #else
        Issue.record("Compiled without DEBUG: this case's body is empty and its green is vacuous.")
        #endif
    }

    @Test("Server URL is dev server in DEBUG")
    func serverURLInDebug() {
        let keys = EnvironmentAPIKeys(
            testflight: "tf_key",
            production: "prod_key"
        )

        #if DEBUG
        #expect(keys.currentServerURL.host == "api.dev.getfeedbackkit.com")
        #expect(keys.currentServerURL.path == "/api/v1")
        #expect(keys.currentServerURL.host != "api.prod.getfeedbackkit.com")
        #else
        Issue.record("Compiled without DEBUG: this case's body is empty and its green is vacuous.")
        #endif
    }

    @Test("Environment name in DEBUG")
    func environmentNameInDebug() {
        let keys = EnvironmentAPIKeys(
            testflight: "tf_key",
            production: "prod_key"
        )

        #if DEBUG
        #expect(keys.currentEnvironmentName == "development (DEBUG)")
        #else
        Issue.record("Compiled without DEBUG: this case's body is empty and its green is vacuous.")
        #endif
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let keys = EnvironmentAPIKeys(
            debug: "debug_key",
            testflight: "tf_key",
            production: "prod_key"
        )

        // Verify keys can be safely passed across concurrency boundaries
        await Task {
            #expect(keys.debug == "debug_key")
            #expect(keys.testflight == "tf_key")
            #expect(keys.production == "prod_key")
        }.value
    }
}
