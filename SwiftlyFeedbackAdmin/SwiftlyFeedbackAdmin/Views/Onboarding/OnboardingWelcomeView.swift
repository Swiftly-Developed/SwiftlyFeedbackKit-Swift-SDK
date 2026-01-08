import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void
    let onLogin: () -> Void

    @State private var animateFeatures = false
    @State private var animateLogo = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let features: [(icon: String, title: String, description: String)] = [
        ("bubble.left.and.bubble.right.fill", "Collect Feedback", "Gather feature requests and bug reports directly from your users"),
        ("chart.bar.xaxis", "Track Analytics", "Monitor user engagement and prioritize based on real data"),
        ("person.3.fill", "Team Collaboration", "Work together with your team to manage and respond to feedback"),
        ("arrow.triangle.branch", "Integrations", "Connect with GitHub, Linear, Notion, Slack, and more")
    ]

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: platformSpacing) {
                    Spacer(minLength: topSpacing(for: geometry))

                    // App Logo and Title
                    VStack(spacing: 16) {
                        Image("FeedbackKit")
                            .resizable()
                            .scaledToFit()
                            .frame(width: logoSize, height: logoSize)
                            .clipShape(RoundedRectangle(cornerRadius: logoCornerRadius))
                            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                            .scaleEffect(animateLogo ? 1 : 0.8)
                            .opacity(animateLogo ? 1 : 0)
                            .accessibilityLabel("SwiftlyFeedback app icon")

                        VStack(spacing: 8) {
                            Text("SwiftlyFeedback")
                                .font(titleFont)
                                .fontWeight(.bold)
                                .accessibilityAddTraits(.isHeader)

                            Text("The feedback platform for modern apps")
                                .font(subtitleFont)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .opacity(animateLogo ? 1 : 0)
                        .offset(y: animateLogo ? 0 : 20)
                    }

                    // Features List - adaptive layout for iPad/Mac
                    if isCompactWidth {
                        // Vertical list for iPhone
                        VStack(spacing: 16) {
                            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                                OnboardingFeatureRow(
                                    icon: feature.icon,
                                    title: feature.title,
                                    description: feature.description
                                )
                                .opacity(animateFeatures ? 1 : 0)
                                .offset(x: animateFeatures ? 0 : -30)
                                .animation(
                                    .easeOut(duration: 0.5).delay(Double(index) * 0.1),
                                    value: animateFeatures
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                    } else {
                        // Grid layout for iPad/Mac
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                                OnboardingFeatureCard(
                                    icon: feature.icon,
                                    title: feature.title,
                                    description: feature.description
                                )
                                .opacity(animateFeatures ? 1 : 0)
                                .scaleEffect(animateFeatures ? 1 : 0.9)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1),
                                    value: animateFeatures
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 20)

                    // Action Buttons
                    VStack(spacing: 16) {
                        Button {
                            onContinue()
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .frame(maxWidth: buttonMaxWidth)
                                .frame(minHeight: 44) // HIG: minimum 44pt touch target
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityHint("Begin creating your account")

                        Button {
                            onLogin()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Already have an account?")
                                    .foregroundStyle(.secondary)
                                Text("Log In")
                                    .fontWeight(.medium)
                            }
                            .frame(minHeight: 44) // HIG: minimum 44pt touch target
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline)
                        .accessibilityLabel("Log in to existing account")
                    }
                    .padding(.bottom, bottomPadding)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateLogo = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateFeatures = true
            }
        }
    }

    // MARK: - Platform-Adaptive Properties

    private var isCompactWidth: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    private var logoSize: CGFloat {
        #if os(macOS)
        return 100
        #else
        return isCompactWidth ? 100 : 120
        #endif
    }

    private var logoCornerRadius: CGFloat {
        logoSize * 0.22 // iOS app icon corner radius ratio
    }

    private var titleFont: Font {
        #if os(macOS)
        return .largeTitle
        #else
        return isCompactWidth ? .title : .largeTitle
        #endif
    }

    private var subtitleFont: Font {
        #if os(macOS)
        return .title3
        #else
        return isCompactWidth ? .body : .title3
        #endif
    }

    private var platformSpacing: CGFloat {
        #if os(macOS)
        return 28
        #else
        return isCompactWidth ? 24 : 32
        #endif
    }

    private var horizontalPadding: CGFloat {
        #if os(macOS)
        return 40
        #else
        return isCompactWidth ? 24 : 40
        #endif
    }

    private var maxContentWidth: CGFloat {
        #if os(macOS)
        return 600
        #else
        return isCompactWidth ? .infinity : 700
        #endif
    }

    private var buttonMaxWidth: CGFloat {
        #if os(macOS)
        return 280
        #else
        return isCompactWidth ? .infinity : 320
        #endif
    }

    private var bottomPadding: CGFloat {
        #if os(macOS)
        return 32
        #else
        return isCompactWidth ? 16 : 32
        #endif
    }

    private func topSpacing(for geometry: GeometryProxy) -> CGFloat {
        #if os(macOS)
        return max(20, geometry.size.height * 0.05)
        #else
        if isCompactWidth {
            return 20
        } else {
            return max(40, geometry.size.height * 0.08)
        }
        #endif
    }
}

// MARK: - Feature Row (iPhone)

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44) // HIG: minimum touch target
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

// MARK: - Feature Card (iPad/Mac)

private struct OnboardingFeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }

    private var cardBackground: some ShapeStyle {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}

#Preview("iPhone") {
    OnboardingWelcomeView(
        onContinue: {},
        onLogin: {}
    )
}

#Preview("iPad") {
    OnboardingWelcomeView(
        onContinue: {},
        onLogin: {}
    )
    .previewDevice("iPad Pro (11-inch)")
}
