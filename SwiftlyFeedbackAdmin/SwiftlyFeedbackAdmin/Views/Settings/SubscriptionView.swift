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

    var body: some View {
        List {
            // Current Plan Section
            currentPlanSection

            // Pro Features Section
            proFeaturesSection

            // Team Features Section
            teamFeaturesSection

            // Coming Soon Section (since RevenueCat is not yet integrated)
            comingSoonSection

            // Restore Purchases Section
            restoreSection
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

    // MARK: - Current Plan Section

    @ViewBuilder
    private var currentPlanSection: some View {
        Section {
            HStack(spacing: 16) {
                // Plan Icon
                ZStack {
                    tierGradient(for: subscriptionService.currentTier)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    Image(systemName: tierIcon(for: subscriptionService.currentTier))
                        .font(.title2)
                        .foregroundStyle(subscriptionService.isPaidSubscriber ? .white : .gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionService.subscriptionStatusText)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if subscriptionService.isPaidSubscriber {
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

                if subscriptionService.isPaidSubscriber {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Current Plan")
        }
    }

    // MARK: - Pro Features Section

    @ViewBuilder
    private var proFeaturesSection: some View {
        Section {
            FeatureRow(
                icon: "folder.fill",
                iconColor: .blue,
                title: "2 Projects",
                description: "Create up to 2 projects",
                isIncluded: subscriptionService.currentTier.meetsRequirement(.pro),
                tierBadge: "Pro"
            )

            FeatureRow(
                icon: "bubble.left.and.bubble.right.fill",
                iconColor: .green,
                title: "Unlimited Feedback",
                description: "No limits on feedback items per project",
                isIncluded: subscriptionService.currentTier.meetsRequirement(.pro),
                tierBadge: "Pro"
            )

            FeatureRow(
                icon: "chart.bar.fill",
                iconColor: .cyan,
                title: "Advanced Analytics",
                description: "MRR tracking and detailed insights",
                isIncluded: subscriptionService.currentTier.meetsRequirement(.pro),
                tierBadge: "Pro"
            )

            FeatureRow(
                icon: "slider.horizontal.3",
                iconColor: .orange,
                title: "Configurable Statuses",
                description: "Customize feedback workflow stages",
                isIncluded: subscriptionService.currentTier.meetsRequirement(.pro),
                tierBadge: "Pro"
            )
        } header: {
            HStack {
                Text("Pro Features")
                Spacer()
                if subscriptionService.currentTier == .pro {
                    Text("Current Plan")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.purple, in: Capsule())
                }
            }
        }
    }

    // MARK: - Team Features Section

    @ViewBuilder
    private var teamFeaturesSection: some View {
        Section {
            FeatureRow(
                icon: "folder.fill.badge.plus",
                iconColor: .indigo,
                title: "Unlimited Projects",
                description: "Create as many projects as you need",
                isIncluded: subscriptionService.isTeamSubscriber,
                tierBadge: "Team"
            )

            FeatureRow(
                icon: "person.2.fill",
                iconColor: .orange,
                title: "Team Members",
                description: "Invite unlimited team members",
                isIncluded: subscriptionService.isTeamSubscriber,
                tierBadge: "Team"
            )

            FeatureRow(
                icon: "link",
                iconColor: .purple,
                title: "Slack Integration",
                description: "Get notifications in Slack channels",
                isIncluded: subscriptionService.isTeamSubscriber,
                tierBadge: "Team"
            )

            FeatureRow(
                icon: "arrow.triangle.branch",
                iconColor: .gray,
                title: "GitHub Integration",
                description: "Push feedback to GitHub issues",
                isIncluded: subscriptionService.isTeamSubscriber,
                tierBadge: "Team"
            )

            FeatureRow(
                icon: "envelope.fill",
                iconColor: .red,
                title: "Email Notifications",
                description: "Automatic email alerts for updates",
                isIncluded: subscriptionService.isTeamSubscriber,
                tierBadge: "Team"
            )
        } header: {
            HStack {
                Text("Team Features")
                Spacer()
                if subscriptionService.isTeamSubscriber {
                    Text("Current Plan")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
                }
            }
        }
    }

    // MARK: - Coming Soon Section

    @ViewBuilder
    private var comingSoonSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple)

                    Text("Subscriptions Coming Soon")
                        .font(.headline)

                    Text("Pro and Team subscriptions will be available in a future update.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 16)
                Spacer()
            }
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

            #if os(iOS)
            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                HStack {
                    Spacer()
                    Text("Manage in App Store")
                        .foregroundStyle(.blue)
                    Spacer()
                }
            }
            #endif
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

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isIncluded: Bool
    var tierBadge: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .fontWeight(.medium)

                    if let badge = tierBadge, !isIncluded {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badge == "Team" ? .blue : .purple, in: Capsule())
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isIncluded ? .green : .secondary)
                .font(.title3)
        }
        .opacity(isIncluded ? 1 : 0.6)
    }
}

// MARK: - Preview

#Preview("Free User") {
    NavigationStack {
        SubscriptionView()
    }
}
