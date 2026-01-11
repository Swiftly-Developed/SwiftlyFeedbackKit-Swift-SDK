//
//  PaywallView.swift
//  SwiftlyFeedbackAdmin
//
//  Created for Feedback Kit subscription system.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    /// The minimum tier required for the feature that triggered the paywall
    let requiredTier: SubscriptionTier

    /// When true, forces showing the actual paywall even if environment override is active.
    /// Use this when triggered by a server 402 response (server doesn't respect client-side override).
    let forceShowPaywall: Bool

    @State private var subscriptionService = SubscriptionService.shared
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var isYearly = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isOverridingTier = false
    @Environment(\.dismiss) private var dismiss

    /// Initialize with a required tier (defaults to .pro for backwards compatibility)
    init(requiredTier: SubscriptionTier = .pro, forceShowPaywall: Bool = false) {
        self.requiredTier = requiredTier
        self.forceShowPaywall = forceShowPaywall
    }

    /// Whether the environment override is active (DEV/TestFlight)
    /// Returns false if forceShowPaywall is true (e.g., triggered by server 402)
    private var hasEnvironmentOverride: Bool {
        if forceShowPaywall {
            return false
        }
        return subscriptionService.hasEnvironmentOverride
    }

    /// Get the package for a specific tier and billing period
    private func package(for tier: SubscriptionTier, yearly: Bool, from offering: Offering) -> Package? {
        let productId: String
        switch tier {
        case .pro:
            productId = yearly ? SubscriptionService.ProductID.proYearly.rawValue : SubscriptionService.ProductID.proMonthly.rawValue
        case .team:
            productId = yearly ? SubscriptionService.ProductID.teamYearly.rawValue : SubscriptionService.ProductID.teamMonthly.rawValue
        case .free:
            return nil
        }
        return offering.availablePackages.first { $0.storeProduct.productIdentifier == productId }
    }

    /// The currently selected package based on tier and billing period
    private func selectedPackage(from offering: Offering) -> Package? {
        package(for: selectedTier, yearly: isYearly, from: offering)
    }

    /// Available tiers to show based on requiredTier
    private var availableTiers: [SubscriptionTier] {
        switch requiredTier {
        case .free, .pro:
            return [.pro, .team]
        case .team:
            return [.team]
        }
    }

    /// Whether we're in a non-production environment where server tier override is available
    private var canUseServerOverride: Bool {
        let env = AppConfiguration.currentEnvironment
        return env == .localhost || env == .development || env == .testflight
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasEnvironmentOverride {
                    environmentOverrideView
                } else {
                    paywallContent
                }
            }
            .navigationTitle(hasEnvironmentOverride ? "Features Unlocked" : "")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(hasEnvironmentOverride ? "Done" : "Cancel") { dismiss() }
                }
            }
            .task {
                if !hasEnvironmentOverride {
                    await subscriptionService.fetchOfferings()
                    // Pre-select required tier if it's Team
                    if requiredTier == .team {
                        selectedTier = .team
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Environment Override View

    @ViewBuilder
    private var environmentOverrideView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: 8) {
                Text("All Features Unlocked")
                    .font(.title)
                    .fontWeight(.bold)

                Text("You're using \(AppConfiguration.currentEnvironment.displayName) environment")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureCheckRow(text: "Unlimited Projects")
                FeatureCheckRow(text: "Unlimited Feedback")
                FeatureCheckRow(text: "Team Members")
                FeatureCheckRow(text: "All Integrations")
                FeatureCheckRow(text: "Advanced Analytics")
            }
            .padding()
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            Text("DEV/TestFlight environments have all features enabled for testing purposes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Got It")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }

    // MARK: - Paywall Content

    @ViewBuilder
    private var paywallContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo with blur background
                logoSection

                // Billing period toggle
                billingPeriodToggle

                // Feature comparison table
                featureComparisonTable

                // Tier selection cards (with pricing)
                if let offerings = subscriptionService.offerings,
                   let current = offerings.current {
                    tierSelectionSection(offering: current)

                    // Subscribe button
                    subscribeButton(offering: current)
                } else if subscriptionService.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    Text("Unable to load subscription options")
                        .foregroundStyle(.secondary)
                        .padding()
                }

                // Restore & Terms
                footerSection
            }
            .padding()
        }
    }

    // MARK: - Logo Section

    @ViewBuilder
    private var logoSection: some View {
        ZStack {
            // Dynamic blur background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.orange.opacity(0.4), Color.orange.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 20)

            VStack(spacing: 8) {
                Image(.feedbackKit)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text("PREMIUM")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Billing Period Toggle

    @ViewBuilder
    private var billingPeriodToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isYearly = false
                }
            } label: {
                Text("Monthly")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isYearly ? Color.clear : Color.accentColor)
                    .foregroundStyle(isYearly ? Color.secondary : Color.white)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isYearly = true
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Yearly")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("-17%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isYearly ? Color.white.opacity(0.2) : Color.green.opacity(0.2))
                        .foregroundStyle(isYearly ? .white : .green)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isYearly ? Color.accentColor : Color.clear)
                .foregroundStyle(isYearly ? .white : .secondary)
            }
            .buttonStyle(.plain)
        }
        #if os(iOS)
        .background(Color(UIColor.secondarySystemBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Feature Comparison Table

    @ViewBuilder
    private var featureComparisonTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("FREE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .frame(width: 50)

                Text("PRO")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.purple)
                    .frame(width: 50)

                Text("TEAM")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                    .frame(width: 50)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Feature rows
            FeatureComparisonRow(
                feature: "Projects",
                freeValue: .text("1"),
                proValue: .text("2"),
                teamValue: .text("∞")
            )

            FeatureComparisonRow(
                feature: "Feedback Requests",
                freeValue: .text("10"),
                proValue: .text("∞"),
                teamValue: .text("∞")
            )

            FeatureComparisonRow(
                feature: "Integrations",
                freeValue: .unavailable,
                proValue: .available,
                teamValue: .available
            )

            FeatureComparisonRow(
                feature: "Advanced Analytics",
                freeValue: .unavailable,
                proValue: .available,
                teamValue: .available
            )

            FeatureComparisonRow(
                feature: "Custom Statuses",
                freeValue: .unavailable,
                proValue: .available,
                teamValue: .available
            )

            FeatureComparisonRow(
                feature: "Team Members",
                freeValue: .unavailable,
                proValue: .unavailable,
                teamValue: .available
            )

            FeatureComparisonRow(
                feature: "Voter Notifications",
                freeValue: .unavailable,
                proValue: .unavailable,
                teamValue: .available,
                isLast: true
            )
        }
        #if os(iOS)
        .background(Color(UIColor.secondarySystemBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Tier Selection Section

    @ViewBuilder
    private func tierSelectionSection(offering: Offering) -> some View {
        HStack(spacing: 12) {
            ForEach(availableTiers, id: \.self) { tier in
                TierSelectionCard(
                    tier: tier,
                    package: package(for: tier, yearly: isYearly, from: offering),
                    isSelected: selectedTier == tier,
                    isRecommended: tier == .pro && availableTiers.count > 1
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTier = tier
                    }
                }
            }
        }
    }

    // MARK: - Subscribe Button

    @ViewBuilder
    private func subscribeButton(offering: Offering) -> some View {
        let currentPackage = selectedPackage(from: offering)
        let tierColor: Color = selectedTier == .team ? .blue : .purple

        VStack(spacing: 12) {
            // DEV-only: Server override button for non-production environments
            if canUseServerOverride {
                Button {
                    Task {
                        await overrideTierOnServer()
                    }
                } label: {
                    HStack {
                        if isOverridingTier {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "hammer.fill")
                            Text("DEV: Unlock \(selectedTier.displayName) on Server")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(subscriptionService.isLoading || isOverridingTier)

                Text("This bypasses StoreKit and updates your server-side subscription tier for testing.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)

                Divider()
                    .padding(.vertical, 4)

                Text("Or subscribe via App Store:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Regular subscribe button
            Button {
                Task {
                    await purchasePackage(currentPackage)
                }
            } label: {
                HStack {
                    if subscriptionService.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Text("Subscribe to \(selectedTier.displayName)")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(currentPackage == nil ? Color.gray : tierColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(currentPackage == nil || subscriptionService.isLoading || isOverridingTier)
        }
    }

    // MARK: - Footer Section

    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") {
                Task {
                    await restorePurchases()
                }
            }
            .font(.subheadline)
            .disabled(subscriptionService.isLoading)

            Text("Payment will be charged to your Apple ID. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://feedbackkit.app/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://feedbackkit.app/privacy")!)
            }
            .font(.caption)
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func purchasePackage(_ package: Package?) async {
        guard let package else { return }

        do {
            try await subscriptionService.purchase(package: package)
            dismiss()
        } catch SubscriptionError.purchaseCancelled {
            // User cancelled - do nothing
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionService.restorePurchases()
            if subscriptionService.isProSubscriber {
                dismiss()
            } else {
                errorMessage = "No previous purchases found"
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// DEV-only: Override subscription tier on the server for testing
    private func overrideTierOnServer() async {
        isOverridingTier = true
        defer { isOverridingTier = false }

        do {
            _ = try await AdminAPIClient.shared.overrideSubscriptionTier(selectedTier)
            // Update client-side tier to match the server override
            #if DEBUG
            subscriptionService.simulatedTier = selectedTier
            #endif
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Feature Comparison Row

enum FeatureValue {
    case available
    case unavailable
    case text(String)
}

struct FeatureComparisonRow: View {
    let feature: String
    let freeValue: FeatureValue
    let proValue: FeatureValue
    let teamValue: FeatureValue
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(feature)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                featureCell(freeValue, color: .secondary)
                    .frame(width: 50)

                featureCell(proValue, color: .purple)
                    .frame(width: 50)

                featureCell(teamValue, color: .blue)
                    .frame(width: 50)
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
    private func featureCell(_ value: FeatureValue, color: Color) -> some View {
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
}

// MARK: - Tier Selection Card

struct TierSelectionCard: View {
    let tier: SubscriptionTier
    let package: Package?
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void

    private var tierColor: Color {
        tier == .team ? .blue : .purple
    }

    private var tierIcon: String {
        tier == .team ? "person.3.fill" : "crown.fill"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Recommended badge or spacer
                if isRecommended {
                    Text("Popular")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tierColor.opacity(0.2))
                        .foregroundStyle(tierColor)
                        .clipShape(Capsule())
                } else {
                    Text(" ")
                        .font(.caption2)
                        .padding(.vertical, 3)
                }

                Image(systemName: tierIcon)
                    .font(.title)
                    .foregroundStyle(tierColor)

                Text(tier.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)

                if let package {
                    Text(priceText(for: package))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? tierColor : .secondary.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding()
            #if os(iOS)
            .background(isSelected ? tierColor.opacity(0.08) : Color(UIColor.secondarySystemBackground))
            #else
            .background(isSelected ? tierColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? tierColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func priceText(for package: Package) -> String {
        let price = package.storeProduct.localizedPriceString
        let productId = package.storeProduct.productIdentifier

        // Check product ID for billing period since packageType may not be set correctly for all packages
        if productId.contains(".monthly") {
            return "\(price)/month"
        } else if productId.contains(".yearly") {
            return "\(price)/year"
        }

        // Fallback to packageType
        switch package.packageType {
        case .monthly:
            return "\(price)/month"
        case .annual:
            return "\(price)/year"
        default:
            return price
        }
    }
}

// MARK: - Feature Check Row

struct FeatureCheckRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview("Pro Required") {
    PaywallView(requiredTier: .pro)
}

#Preview("Team Required") {
    PaywallView(requiredTier: .team)
}
