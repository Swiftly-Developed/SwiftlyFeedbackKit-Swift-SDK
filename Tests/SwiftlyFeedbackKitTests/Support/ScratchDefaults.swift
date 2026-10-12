import Foundation
import Testing

/// A `UserDefaults` domain that belongs to exactly one `@Test`.
///
/// `TRANSLATION01` §18 requires the target store be unit-testable without a device, and
/// the store's `init(defaults:)` is what makes that hermetic as well as device-free.
/// `UserDefaults.standard` in a test is process-global shared state, and the failure it
/// produces is the worst kind: a case that passes having read a value a *sibling* case
/// wrote, or having written the developer's real defaults domain and left it there.
///
/// **`UserDefaults(suiteName:)` returns an `Optional`, and `?? .standard` compiles, reads
/// naturally, and silently reinstates exactly the process-wide mutation this type exists
/// to remove — while every assertion stays green.** It is `#require`d here, once, so no
/// case can spell that fallback.
///
/// Modelled on the Admin target's `ScratchPreferenceStore`; this package's test target has
/// no equivalent, which is the only reason a second one exists.
struct ScratchDefaults {
    /// The domain name. Run-unique, so two cases in the same process cannot collide.
    let suiteName: String

    /// The store itself. Hand it to the defaults-backed type under test.
    ///
    /// Deliberately not spelled with the store's own initializer here: §8.4's G22c pins
    /// the suite's store-construction count to its scratch-domain count, and a mention in
    /// a doc comment counts.
    let defaults: UserDefaults

    /// - Parameter label: Folded into the domain name so a leaked domain names its case.
    init(_ label: String = #function) throws {
        let sanitized = label.replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let name = "com.swiftly-developed.SwiftlyFeedbackKitTests.\(sanitized).\(UUID().uuidString)"

        let store = try #require(
            UserDefaults(suiteName: name),
            """
            UserDefaults(suiteName: "\(name)") returned nil. Do NOT recover with \
            `?? .standard` — that reinstates the process-wide mutation this type exists to \
            remove, and every assertion downstream stays green while proving nothing.
            """
        )

        // A scratch store that had silently fallen back to the process default would make
        // every "absent from the domain" assertion in these suites read the developer's
        // real defaults. Prove the isolation rather than assume it. This is the one place
        // in the target that may name the process store, and it names it only to assert
        // that it is NOT the one being used.
        #expect(
            store !== UserDefaults.standard,
            "The scratch store is the process default — this case is not isolated."
        )

        self.suiteName = name
        self.defaults = store
    }

    /// Reads the raw value under a key, bypassing the store under test.
    ///
    /// The absence oracle asserts on the *domain*, not on the store's own read, so an
    /// implementation whose read and write are wrong in the same direction cannot satisfy
    /// it by agreeing with itself.
    func rawValue(forKey key: String) -> Any? {
        defaults.object(forKey: key)
    }

    /// Removes the whole domain. Nothing here is load-bearing for correctness — that is
    /// the point of a per-case store — so a failure skipping it costs nothing but disk.
    ///
    /// Note: this clears the domain's *contents*; a zero-content `.plist` can remain in
    /// `~/Library/Preferences/`. Harmless, and recorded so a leftover file is not
    /// mistaken for a leak.
    func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
