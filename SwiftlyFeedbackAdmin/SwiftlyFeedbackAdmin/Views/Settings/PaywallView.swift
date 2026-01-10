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

    @State private var subscriptionService = SubscriptionService.shared
    @State private var selectedPackage: Package?
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    /// Initialize with a required tier (defaults to .pro for backwards compatibility)
    init(requiredTier: SubscriptionTier = .pro) {
        self.requiredTier = requiredTier
    }

    /// Filter packages to show only relevant tiers based on the required tier
    private func filteredPackages(from offering: Offering) -> [Package] {
        offering.availablePackages.filter { package in
            let productId = package.storeProduct.productIdentifier
            switch requiredTier {
            case .free:
                // Free tier doesn't need paywall, but if shown, show all
                return true
            case .pro:
                // For Pro requirement, show only Pro packages
                return productId.contains(".pro.")
            case .team:
                // For Team requirement, show only Team packages
                return productId.contains(".team.")
            }
        }
    }

    private var navigationTitle: String {
        switch requiredTier {
        case .free:
            return "Upgrade"
        case .pro:
            return "Upgrade to Pro"
        case .team:
            return "Upgrade to Team"
        }
    }

    private var heroTitle: String {
        switch requiredTier {
        case .free:
            return "Upgrade Your Plan"
        case .pro:
            return "Unlock Pro Features"
        case .team:
            return "Unlock Team Features"
        }
    }

    private var accentColor: Color {
        requiredTier == .team ? .blue : .purple
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero section
                    heroSection

                    // Package selection
                    if let offerings = subscriptionService.offerings,
                       let current = offerings.current {
                        packageSelectionSection(offering: current)
                    } else if subscriptionService.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        Text("Unable to load subscription options")
                            .foregroundStyle(.secondary)
                            .padding()
                    }

                    // Subscribe button
                    subscribeButton

                    // Restore & Terms
                    footerSection
                }
                .padding()
            }
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await subscriptionService.fetchOfferings()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: requiredTier == .team ? "person.3.fill" : "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(.linearGradient(
                    colors: requiredTier == .team ? [.blue, .cyan] : [.purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text(heroTitle)
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                if requiredTier == .team {
                    // Team features
                    FeatureCheckRow(text: "Unlimited Projects")
                    FeatureCheckRow(text: "Invite Team Members")
                    FeatureCheckRow(text: "All Integrations (Slack, GitHub, etc.)")
                    FeatureCheckRow(text: "Everything in Pro")
                } else {
                    // Pro features
                    FeatureCheckRow(text: "2 Projects (up from 1)")
                    FeatureCheckRow(text: "Unlimited Feedback per Project")
                    FeatureCheckRow(text: "Advanced Analytics & MRR Tracking")
                    FeatureCheckRow(text: "Configurable Status Workflow")
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Package Selection

    @ViewBuilder
    private func packageSelectionSection(offering: Offering) -> some View {
        let packages = filteredPackages(from: offering)
        VStack(spacing: 12) {
            ForEach(packages, id: \.identifier) { package in
                PackageOptionView(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    accentColor: accentColor
                ) {
                    selectedPackage = package
                }
            }
        }
    }

    // MARK: - Subscribe Button

    @ViewBuilder
    private var subscribeButton: some View {
        Button {
            Task {
                await purchaseSelectedPackage()
            }
        } label: {
            HStack {
                if subscriptionService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Text("Subscribe")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedPackage == nil ? Color.gray : accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(selectedPackage == nil || subscriptionService.isLoading)
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

    private func purchaseSelectedPackage() async {
        guard let package = selectedPackage else { return }

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
}

// MARK: - Package Option View

struct PackageOptionView: View {
    let package: Package
    let isSelected: Bool
    var accentColor: Color = .purple
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(package.storeProduct.localizedTitle)
                            .fontWeight(.semibold)

                        if package.packageType == .annual {
                            Text("Save 17%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text(priceText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? accentColor : .secondary)
            }
            .padding()
            #if os(iOS)
            .background(isSelected ? accentColor.opacity(0.1) : Color(UIColor.secondarySystemBackground))
            #else
            .background(isSelected ? accentColor.opacity(0.1) : Color(NSColor.windowBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var priceText: String {
        let price = package.storeProduct.localizedPriceString
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

#Preview {
    PaywallView()
}
