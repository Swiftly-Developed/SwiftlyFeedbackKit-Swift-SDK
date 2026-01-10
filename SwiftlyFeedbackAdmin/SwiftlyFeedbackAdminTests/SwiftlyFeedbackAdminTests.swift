//
//  SwiftlyFeedbackAdminTests.swift
//  SwiftlyFeedbackAdminTests
//
//  Created by Ben Van Aken on 03/01/2026.
//

import Testing
@testable import SwiftlyFeedbackAdmin

struct SwiftlyFeedbackAdminTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
}

// MARK: - Subscription Tier Tests

struct SubscriptionTierTests {

    @Test func freeTierMeetsOnlyFreeRequirement() {
        let tier = SubscriptionTier.free
        #expect(tier.meetsRequirement(.free) == true)
        #expect(tier.meetsRequirement(.pro) == false)
        #expect(tier.meetsRequirement(.team) == false)
    }

    @Test func proTierMeetsFreeAndProRequirements() {
        let tier = SubscriptionTier.pro
        #expect(tier.meetsRequirement(.free) == true)
        #expect(tier.meetsRequirement(.pro) == true)
        #expect(tier.meetsRequirement(.team) == false)
    }

    @Test func teamTierMeetsAllRequirements() {
        let tier = SubscriptionTier.team
        #expect(tier.meetsRequirement(.free) == true)
        #expect(tier.meetsRequirement(.pro) == true)
        #expect(tier.meetsRequirement(.team) == true)
    }

    @Test func freeTierLimits() {
        let tier = SubscriptionTier.free
        #expect(tier.maxProjects == 1)
        #expect(tier.maxFeedbackPerProject == 10)
        #expect(tier.canInviteMembers == false)
        #expect(tier.hasIntegrations == false)
    }

    @Test func proTierLimits() {
        let tier = SubscriptionTier.pro
        #expect(tier.maxProjects == 2)
        #expect(tier.maxFeedbackPerProject == nil)
        #expect(tier.canInviteMembers == false)
        #expect(tier.hasIntegrations == false)
    }

    @Test func teamTierLimits() {
        let tier = SubscriptionTier.team
        #expect(tier.maxProjects == nil)
        #expect(tier.maxFeedbackPerProject == nil)
        #expect(tier.canInviteMembers == true)
        #expect(tier.hasIntegrations == true)
    }
}
