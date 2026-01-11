//
//  SubscriptionView.swift
//  SwiftlyFeedbackAdmin
//
//  Created by Ben Van Aken on 04/01/2026.
//

import SwiftUI

struct SubscriptionView: View {
    @State private var subscriptionService = SubscriptionService.shared
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showPaywall = false
    @State private var paywallRequiredTier: SubscriptionTier = .pro

    var body: some View {
        List {
            // Current Plan Section
            currentPlanSection

            // Upgrade Section (for users who can upgrade)
            if canShowUpgradeSection {
                upgradeSection
            }

            // Feature Comparison Table
            featureComparisonSection

            // Manage Subscription Section (for paid subscribers)
            if subscriptionService.isPaidSubscriber && !subscriptionService.hasEnvironmentOverride {
                manageSubscriptionSection
            }

            // Restore Purchases Section
            restoreSection
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(requiredTier: paywallRequiredTier)
        }
        .navigationTitle("Subscription")
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK") {}
        } message: {
            Text(restoreMessage)
        }
        .alert("Error", isPresented: $subscriptionService.showError) {
            Button("OK") {
                subscriptionService.clearError()
            }
        } message: {
            Text(subscriptionService.errorMessage ?? "An error occurred")
        }
    }

    /// Whether to show the upgrade section
    /// Shows for free users, and Pro users who might want Team
    private var canShowUpgradeSection: Bool {
        if subscriptionService.hasEnvironmentOverride {
            return false
        }
        // Show if user is not at max tier (Team)
        return displayTier != .team
    }

    // MARK: - Current Plan Section

    /// The tier to display (uses effectiveTier to respect environment override)
    private var displayTier: SubscriptionTier {
        subscriptionService.effectiveTier
    }

    @ViewBuilder
    private var currentPlanSection: some View {
        Section {
            HStack(spacing: 16) {
                // Plan Icon
                ZStack {
                    tierGradient(for: displayTier)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    Image(systemName: tierIcon(for: displayTier))
                        .font(.title2)
                        .foregroundStyle(displayTier != .free ? .white : .gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(displayTier.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if subscriptionService.hasEnvironmentOverride {
                            Text("DEV")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange, in: Capsule())
                        }
                    }

                    if subscriptionService.hasEnvironmentOverride {
                        Text("All features unlocked for testing")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    } else if subscriptionService.isPaidSubscriber {
                        if let expirationDate = subscriptionService.subscriptionExpirationDate {
                            if subscriptionService.willRenew {
                                Text("Renews \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Expires \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                    } else {
                        Text("Upgrade to unlock all features")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if displayTier != .free {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(subscriptionService.hasEnvironmentOverride ? .orange : .green)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Current Plan")
        }
    }

    // MARK: - Feature Comparison Section

    @ViewBuilder
    private var featureComparisonSection: some View {
        Section {
            featureComparisonTable
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } header: {
            Text("Compare Plans")
        } footer: {
            Text("Upgrade anytime to unlock more features. All plans include core feedback collection.")
        }
    }

    @ViewBuilder
    private var featureComparisonTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)

                tierHeaderCell(tier: .free, label: "FREE")
                tierHeaderCell(tier: .pro, label: "PRO")
                tierHeaderCell(tier: .team, label: "TEAM")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Feature rows
            SubscriptionFeatureRow(
                feature: "Projects",
                freeValue: .text("1"),
                proValue: .text("2"),
                teamValue: .text("∞"),
                currentTier: displayTier
            )

            SubscriptionFeatureRow(
                feature: "Feedback per Project",
                freeValue: .text("10"),
                proValue: .text("∞"),
                teamValue: .text("∞"),
                currentTier: displayTier
            )

            SubscriptionFeatureRow(
                feature: "Integrations",
                freeValue: .unavailable,
                proValue: .available,
                teamValue: .available,
                currentTier: displayTier
            )

            SubscriptionFeatureRow(
                feature: "Advanced Analytics",
                freeValue: .unavailable,
                proValue: .available,
                teamValue: .available,
                currentTier: displayTier
            )

            SubscriptionFeatureRow(
                feature: "Custom Statuses",
                freeValue: .unavailable,
                proValue: .available,
                teamValue: .available,
                currentTier: displayTier
            )

            SubscriptionFeatureRow(
                feature: "Comment Notifications",
                freeValue: .unavailable,
                proValue: .available,
                teamValue: .available,
                currentTier: displayTier
            )

            SubscriptionFeatureRow(
                feature: "Team Members",
                freeValue: .unavailable,
                proValue: .unavailable,
                teamValue: .available,
                currentTier: displayTier
            )

            SubscriptionFeatureRow(
                feature: "Voter Notifications",
                freeValue: .unavailable,
                proValue: .unavailable,
                teamValue: .available,
                currentTier: displayTier,
                isLast: true
            )
        }
        #if os(iOS)
        .background(Color(UIColor.secondarySystemBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func tierHeaderCell(tier: SubscriptionTier, label: String) -> some View {
        let isCurrentTier = displayTier == tier
        let color: Color = {
            switch tier {
            case .free: return .secondary
            case .pro: return .purple
            case .team: return .blue
            }
        }()

        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(color)

            if isCurrentTier {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 55)
    }

    // MARK: - Upgrade Section

    /// The next tier to upgrade to
    private var upgradeTier: SubscriptionTier {
        displayTier == .free ? .pro : .team
    }

    /// Upgrade section icon and colors based on target tier
    private var upgradeIcon: String {
        upgradeTier == .pro ? "crown.fill" : "person.3.fill"
    }

    private var upgradeGradientColors: [Color] {
        upgradeTier == .pro ? [.purple, .pink] : [.blue, .cyan]
    }

    private var upgradeTitle: String {
        "Upgrade to \(upgradeTier.displayName)"
    }

    private var upgradeSubtitle: String {
        switch upgradeTier {
        case .pro:
            return "Unlock 2 projects, unlimited feedback, and integrations"
        case .team:
            return "Unlock unlimited projects and team collaboration"
        case .free:
            return ""
        }
    }

    @ViewBuilder
    private var upgradeSection: some View {
        Section {
            Button {
                paywallRequiredTier = upgradeTier
                showPaywall = true
            } label: {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: upgradeIcon)
                            .font(.system(size: 40))
                            .foregroundStyle(.linearGradient(
                                colors: upgradeGradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))

                        Text(upgradeTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(upgradeSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Manage Subscription Section

    /// URL to open App Store subscriptions management
    private var manageSubscriptionsURL: URL {
        #if os(iOS)
        URL(string: "https://apps.apple.com/account/subscriptions")!
        #else
        // macOS uses a different URL scheme for subscription management
        URL(string: "macappstores://apps.apple.com/account/subscriptions")!
        #endif
    }

    @ViewBuilder
    private var manageSubscriptionSection: some View {
        Section {
            Link(destination: manageSubscriptionsURL) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Subscription")
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text("Change plan or cancel in App Store")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Subscription Management")
        } footer: {
            Text("You can change your plan, update payment method, or cancel your subscription through the App Store.")
        }
    }

    // MARK: - Restore Section

    @ViewBuilder
    private var restoreSection: some View {
        Section {
            Button {
                Task {
                    await restorePurchases()
                }
            } label: {
                HStack {
                    Spacer()
                    if subscriptionService.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Restore Purchases")
                    }
                    Spacer()
                }
            }
            .disabled(subscriptionService.isLoading)
        } footer: {
            Text("Restore purchases if you've previously subscribed on another device.")
        }
    }

    // MARK: - Helpers

    private func tierGradient(for tier: SubscriptionTier) -> some View {
        Group {
            switch tier {
            case .free:
                Color.gray.opacity(0.3)
            case .pro:
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .team:
                LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func tierIcon(for tier: SubscriptionTier) -> String {
        switch tier {
        case .free: return "person.fill"
        case .pro: return "crown.fill"
        case .team: return "person.3.fill"
        }
    }

    // MARK: - Actions

    private func restorePurchases() async {
        do {
            try await subscriptionService.restorePurchases()
            switch subscriptionService.currentTier {
            case .team:
                restoreMessage = "Your Team subscription has been restored!"
            case .pro:
                restoreMessage = "Your Pro subscription has been restored!"
            case .free:
                restoreMessage = "No active subscriptions found."
            }
            showRestoreAlert = true
        } catch SubscriptionError.notImplemented {
            restoreMessage = SubscriptionError.notImplemented.localizedDescription
            showRestoreAlert = true
        } catch {
            // Other errors are handled by the service
        }
    }
}

// MARK: - Subscription Feature Row

/// A row in the feature comparison table that highlights the current tier
struct SubscriptionFeatureRow: View {
    let feature: String
    let freeValue: FeatureValue
    let proValue: FeatureValue
    let teamValue: FeatureValue
    let currentTier: SubscriptionTier
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(feature)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                featureCell(freeValue, tier: .free)
                    .frame(width: 55)

                featureCell(proValue, tier: .pro)
                    .frame(width: 55)

                featureCell(teamValue, tier: .team)
                    .frame(width: 55)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    @ViewBuilder
    private func featureCell(_ value: FeatureValue, tier: SubscriptionTier) -> some View {
        let isCurrentTier = currentTier == tier
        let color: Color = {
            switch tier {
            case .free: return .secondary
            case .pro: return .purple
            case .team: return .blue
            }
        }()

        Group {
            switch value {
            case .available:
                Image(systemName: "checkmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            case .unavailable:
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary.opacity(0.4))
            case .text(let text):
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            isCurrentTier ? color.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}

// MARK: - Preview

#Preview("Free User") {
    NavigationStack {
        SubscriptionView()
    }
}
