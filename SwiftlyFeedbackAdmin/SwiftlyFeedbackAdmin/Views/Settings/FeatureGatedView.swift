//
//  FeatureGatedView.swift
//  SwiftlyFeedbackAdmin
//
//  A wrapper view that gates content based on subscription tier.
//  Shows a lock overlay for gated features and presents PaywallView on tap.
//

import SwiftUI

/// A view that wraps content and gates it based on subscription tier requirements.
/// If the user doesn't have the required tier, shows a lock overlay and presents
/// the paywall when tapped.
///
/// When running in DEV/TestFlight environments, all features are unlocked and a
/// "DEV MODE" badge is shown to indicate the override is active.
struct FeatureGatedView<Content: View>: View {
    let requiredTier: SubscriptionTier
    let featureName: String
    @ViewBuilder let content: () -> Content

    @State private var subscriptionService = SubscriptionService.shared
    @State private var showPaywall = false

    /// Whether access is granted via environment override (not actual subscription)
    private var isEnvironmentOverrideActive: Bool {
        subscriptionService.hasEnvironmentOverride &&
        !subscriptionService.currentTier.meetsRequirement(requiredTier)
    }

    var body: some View {
        if subscriptionService.meetsRequirement(requiredTier) {
            content()
                .overlay(alignment: .topTrailing) {
                    // Show DEV MODE badge if access is via environment override
                    if isEnvironmentOverrideActive {
                        devModeBadge
                    }
                }
        } else {
            Button {
                showPaywall = true
            } label: {
                content()
                    .opacity(0.5)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.title2)
                            Text(requiredTier.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) {
                PaywallView(requiredTier: requiredTier)
            }
        }
    }

    /// Badge indicating feature is unlocked via environment override
    private var devModeBadge: some View {
        Text("DEV")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.orange, in: Capsule())
            .padding(4)
    }
}

/// A button that checks subscription tier before executing action.
/// If tier requirement is not met, shows the paywall instead.
/// Respects environment override for DEV/TestFlight environments.
struct SubscriptionGatedButton<Label: View>: View {
    let requiredTier: SubscriptionTier
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var subscriptionService = SubscriptionService.shared
    @State private var showPaywall = false

    var body: some View {
        Button {
            if subscriptionService.meetsRequirement(requiredTier) {
                action()
            } else {
                showPaywall = true
            }
        } label: {
            label()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(requiredTier: requiredTier)
        }
    }
}

/// A view modifier that adds a "Pro" or "Team" badge to indicate tier requirement.
/// Shows "DEV" badge instead when environment override is active.
struct TierBadgeModifier: ViewModifier {
    let tier: SubscriptionTier

    @State private var subscriptionService = SubscriptionService.shared

    /// Whether access is granted via environment override (not actual subscription)
    private var isEnvironmentOverrideActive: Bool {
        subscriptionService.hasEnvironmentOverride &&
        !subscriptionService.currentTier.meetsRequirement(tier)
    }

    func body(content: Content) -> some View {
        HStack(spacing: 6) {
            content

            if !subscriptionService.meetsRequirement(tier) {
                // User doesn't have access even with environment override
                Text(tier.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tier == .team ? .blue : .purple, in: Capsule())
            } else if isEnvironmentOverrideActive {
                // User has access via environment override - show DEV badge
                Text("DEV")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange, in: Capsule())
            }
        }
    }
}

extension View {
    /// Adds a tier badge to indicate the required subscription level.
    func tierBadge(_ tier: SubscriptionTier) -> some View {
        modifier(TierBadgeModifier(tier: tier))
    }
}

// MARK: - Previews

#Preview("Locked Feature") {
    FeatureGatedView(requiredTier: .pro, featureName: "Pro Feature") {
        VStack {
            Image(systemName: "star.fill")
                .font(.largeTitle)
            Text("Premium Content")
        }
        .padding()
        .background(Color.blue.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}

#Preview("Unlocked Feature") {
    FeatureGatedView(requiredTier: .free, featureName: "Free Feature") {
        VStack {
            Image(systemName: "star.fill")
                .font(.largeTitle)
            Text("Free Content")
        }
        .padding()
        .background(Color.green.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}
