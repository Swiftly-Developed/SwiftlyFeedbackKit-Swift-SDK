import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                heroSection
                featuresSection
                howItWorksSection
                getStartedSection
            }
            .padding()
        }
        .background(.background.secondary)
        .navigationTitle("Feedback Kit")
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 60))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Collect & Manage User Feedback")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)

            Text("Feedback Kit helps you gather valuable insights from your users, prioritize features, and build better products together.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Features")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                FeatureRow(
                    icon: "lightbulb.fill",
                    iconColor: .yellow,
                    title: "Feature Requests",
                    description: "Users can submit ideas for new features"
                )

                FeatureRow(
                    icon: "ladybug.fill",
                    iconColor: .red,
                    title: "Bug Reports",
                    description: "Easily report issues with detailed descriptions"
                )

                FeatureRow(
                    icon: "hand.thumbsup.fill",
                    iconColor: .blue,
                    title: "Voting System",
                    description: "Let users vote on what matters most"
                )

                FeatureRow(
                    icon: "text.bubble.fill",
                    iconColor: .green,
                    title: "Comments",
                    description: "Engage with users through discussions"
                )

                FeatureRow(
                    icon: "bell.badge.fill",
                    iconColor: .orange,
                    title: "Status Updates",
                    description: "Keep users informed on progress"
                )
            }
            .padding()
            .background(.background, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - How It Works Section

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How It Works")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                StepRow(
                    number: 1,
                    title: "Configure",
                    description: "Set up your email and preferences in Settings"
                )

                StepRow(
                    number: 2,
                    title: "Browse Feedback",
                    description: "View existing feedback and vote on ideas you like"
                )

                StepRow(
                    number: 3,
                    title: "Submit Ideas",
                    description: "Share your own feature requests or bug reports"
                )
            }
            .padding()
            .background(.background, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - Get Started Section

    private var getStartedSection: some View {
        VStack(spacing: 12) {
            Text("Ready to get started?")
                .font(.headline)

            Text("Head to the Settings tab to configure your profile, then explore the Feedback tab to start participating!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.blue.opacity(0.1), in: .rect(cornerRadius: 16))
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Step Row

struct StepRow: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.blue, in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    HomeView()
}
