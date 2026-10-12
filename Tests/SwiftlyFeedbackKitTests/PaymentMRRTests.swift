//
//  PaymentMRRTests.swift
//  SwiftlyFeedbackKitTests
//
//  `QA-UNIT13-VOTES` `-10` — the SDK's four MRR normalizations, at
//  binary-representable fixtures.
//

import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// `SwiftlyFeedback.Payment.mrr` is the one MRR function in the whole workspace
/// that is already pure and already reachable (`QA-UNIT13-VOTES` §4.1). It is
/// Swift-SDK-only — measured, the RN/Flutter/Kotlin SDKs carry no `mrr` at all
/// and the JS SDK only a pass-through field (F7) — so this suite has no
/// cross-client agreement leg to mirror.
///
/// Fixture discipline (spec §4.5, AGENTS.md line 303): every exact `==` below is
/// at a value whose quotient is exactly representable in `Double` — `120/12`,
/// `30/3`, and `12 × (52/12)` (verified: exactly `52.0`). A realistic-looking
/// amount like `9.99 / 3.0` round-tripping is luck, not a contract, and is
/// deliberately not asserted.
@Suite("PaymentMRRTests")
struct PaymentMRRTests {

    // MARK: - QA-UNIT13-10 — the four normalizations

    @Test func monthlyIsTheIdentity() {
        #expect(SwiftlyFeedback.Payment.monthly(10).mrr == 10)
        #expect(SwiftlyFeedback.Payment.monthly(0).mrr == 0)
        #expect(SwiftlyFeedback.Payment.monthly(123.5).mrr == 123.5)
    }

    @Test func yearlyDividesByTwelve() {
        // Red when `.yearly` divides by 52 (weeks) or anything but 12.
        #expect(SwiftlyFeedback.Payment.yearly(120).mrr == 10)
        #expect(SwiftlyFeedback.Payment.yearly(0).mrr == 0)
    }

    @Test func quarterlyDividesByThree() {
        // Red when `.quarterly` divides by 4 — the "calendar quarter" correction
        // someone will make in good faith.
        #expect(SwiftlyFeedback.Payment.quarterly(30).mrr == 10)
    }

    @Test func weeklyUsesFiftyTwoTwelfthsWeeksPerMonth() {
        // 12 × (52/12) is exactly 52.0 in Double (verified before authoring).
        // Red when the constant becomes 4.0 weeks/month: that yields 48, not 52.
        let mrr = SwiftlyFeedback.Payment.weekly(12).mrr
        #expect(mrr == 52)
        #expect(mrr != 48, "4.0 weeks-per-month is the plausible wrong constant")
    }

    /// The pairwise-distinctness clause: for one amount, the four frequencies
    /// give four different numbers. Catches a `switch` arm copy-pasted without
    /// editing its divisor — `.quarterly` and `.yearly` both returning
    /// `amount / 12` are two real, plausible numbers no per-case check
    /// distinguishes.
    @Test func theFourFrequenciesArePairwiseDistinctForOneAmount() {
        let amount = 12.0
        let mrrs = [
            SwiftlyFeedback.Payment.weekly(amount).mrr,     // 52
            SwiftlyFeedback.Payment.monthly(amount).mrr,    // 12
            SwiftlyFeedback.Payment.quarterly(amount).mrr,  // 4
            SwiftlyFeedback.Payment.yearly(amount).mrr,     // 1
        ]
        #expect(Set(mrrs).count == 4, "two frequencies collapsed to one value: \(mrrs)")
    }
}
