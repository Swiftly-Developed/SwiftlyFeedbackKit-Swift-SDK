import Testing
import Foundation
@testable import SwiftlyFeedbackKit

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
        #endif
    }

    @Test("Server URL is localhost in DEBUG")
    func serverURLInDebug() {
        let keys = EnvironmentAPIKeys(
            testflight: "tf_key",
            production: "prod_key"
        )

        #if DEBUG
        #expect(keys.currentServerURL.host == "localhost")
        #expect(keys.currentServerURL.port == 8080)
        #endif
    }

    @Test("Environment name in DEBUG")
    func environmentNameInDebug() {
        let keys = EnvironmentAPIKeys(
            testflight: "tf_key",
            production: "prod_key"
        )

        #if DEBUG
        #expect(keys.currentEnvironmentName == "localhost (DEBUG)")
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
