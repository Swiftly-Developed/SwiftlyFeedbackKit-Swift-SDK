import SwiftUI

// MARK: - Developer Center View

struct DeveloperCenterView: View {
    @Bindable var projectViewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    var isStandaloneWindow: Bool = false

    @State private var selectedProject: ProjectListItem?
    @State private var isGenerating = false
    @State private var generationResult: GenerationResult?
    @State private var showingResult = false
    @State private var showingFullResetConfirmation = false

    // Generation options
    @State private var projectCount = 3
    @State private var feedbackCount = 10
    @State private var commentCount = 5

    // Server environment
    @State private var appConfiguration = AppConfiguration.shared
    @State private var pendingEnvironment: AppEnvironment?
    @State private var pendingEnvironmentName: String = ""  // Cached name for alert title
    @State private var showingEnvironmentChangeConfirmation = false
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?

    // Subscription
    @State private var subscriptionService = SubscriptionService.shared
    @State private var selectedPreviewTier: SubscriptionTier = .free
    @State private var isSavingTier = false
    @State private var tierSaveError: String?

    init(projectViewModel: ProjectViewModel, isStandaloneWindow: Bool = false) {
        self.projectViewModel = projectViewModel
        self.isStandaloneWindow = isStandaloneWindow
    }

    struct GenerationResult: Identifiable {
        let id = UUID()
        let success: Bool
        let message: String
        let details: [String]
    }

    var body: some View {
        NavigationStack {
            Form {
                // Warning Banner
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "hammer.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Developer Mode")
                                .font(.headline)
                            Text(BuildEnvironment.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)
                }

                // Data Retention Warning (non-production only)
                if appConfiguration.environment != .production {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.badge.exclamationmark.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("7-Day Data Retention")
                                    .font(.headline)
                                Text("Feedback on \(appConfiguration.environment.displayName) is automatically deleted after 7 days.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Server Environment
                Section {
                    // Environment picker (if switching is allowed)
                    if appConfiguration.canSwitchEnvironment {
                        ForEach(appConfiguration.availableEnvironments, id: \.self) { env in
                            Button {
                                if env != appConfiguration.environment {
                                    pendingEnvironment = env
                                    pendingEnvironmentName = env.displayName
                                    showingEnvironmentChangeConfirmation = true
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(env.color)
                                        .frame(width: 8, height: 8)
                                    Text(env.displayName)
                                    Spacer()
                                    if env == appConfiguration.environment {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // Show current environment (read-only)
                        HStack {
                            Label("Server", systemImage: "server.rack")
                            Spacer()
                            Text(appConfiguration.environment.displayName)
                                .foregroundStyle(.secondary)
                            Circle()
                                .fill(appConfiguration.environment.color)
                                .frame(width: 8, height: 8)
                        }
                    }

                    // Show current base URL
                    HStack {
                        Label("Base URL", systemImage: "link")
                        Spacer()
                        Text(appConfiguration.baseURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    // Reset and test buttons (only if switching is allowed)
                    if appConfiguration.canSwitchEnvironment {
                        Button("Reset to Default") {
                            appConfiguration.resetToDefault()
                            Task {
                                await AdminAPIClient.shared.updateBaseURL()
                                await testConnection()
                            }
                        }
                    }

                    // Test connection button
                    Button {
                        Task {
                            await testConnection()
                        }
                    } label: {
                        HStack {
                            Label("Test Connection", systemImage: "network")
                            if isTestingConnection {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(isTestingConnection || isGenerating)

                    // Connection test result
                    if let result = connectionTestResult {
                        HStack {
                            Image(systemName: result.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.contains("✅") ? .green : .red)
                            Text(result)
                                .font(.caption)
                        }
                    }
                } header: {
                    Label("Server Environment", systemImage: "server.rack")
                } footer: {
                    if appConfiguration.canSwitchEnvironment {
                        Text("Select the server environment. Localhost is for local backend testing.")
                    } else {
                        Text("Production builds automatically connect to the production server.")
                    }
                }

                // Feature Access (only shown in non-production environments)
                featureAccessSection

                // Subscription Simulation (DEBUG only)
                #if DEBUG
                subscriptionSimulationSection
                #endif

                // Project Generation
                Section {
                    Stepper("Projects: \(projectCount)", value: $projectCount, in: 1...10)

                    Button {
                        Task {
                            await generateProjects()
                        }
                    } label: {
                        Label("Generate Dummy Projects", systemImage: "folder.badge.plus")
                    }
                    .disabled(isGenerating)
                } header: {
                    Text("Projects")
                } footer: {
                    Text("Creates \(projectCount) dummy project(s) with random names.")
                }

                // Feedback Generation
                Section {
                    if projectViewModel.projects.isEmpty {
                        Text("No projects available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Target Project", selection: $selectedProject) {
                            Text("Select a project").tag(nil as ProjectListItem?)
                            ForEach(projectViewModel.projects) { project in
                                Text(project.name).tag(project as ProjectListItem?)
                            }
                        }

                        Stepper("Feedback items: \(feedbackCount)", value: $feedbackCount, in: 1...50)

                        Button {
                            Task {
                                await generateFeedback()
                            }
                        } label: {
                            Label("Generate Dummy Feedback", systemImage: "plus.bubble")
                        }
                        .disabled(isGenerating || selectedProject == nil)
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Creates \(feedbackCount) dummy feedback item(s) for the selected project.")
                }

                // Comment Generation
                Section {
                    Stepper("Comments per feedback: \(commentCount)", value: $commentCount, in: 1...20)

                    Button {
                        Task {
                            await generateComments()
                        }
                    } label: {
                        Label("Generate Dummy Comments", systemImage: "text.bubble")
                    }
                    .disabled(isGenerating || selectedProject == nil)
                } header: {
                    Text("Comments")
                } footer: {
                    Text("Adds \(commentCount) comment(s) to each feedback item in the selected project.")
                }

                // Resets Section
                Section {
                    // Onboarding Status
                    HStack {
                        Label("Onboarding", systemImage: "figure.walk.arrival")
                        Spacer()
                        Text(OnboardingManager.shared.hasCompletedOnboarding ? "Completed" : "Not Completed")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        resetOnboarding()
                    } label: {
                        Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(isGenerating || !OnboardingManager.shared.hasCompletedOnboarding)

                    // Keychain Status
                    HStack {
                        Label("Auth Token", systemImage: "key.fill")
                        Spacer()
                        Text(KeychainService.getToken() != nil ? "Stored" : "None")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        clearAuthToken()
                    } label: {
                        Label("Clear Auth Token", systemImage: "key.slash")
                    }
                    .disabled(isGenerating || KeychainService.getToken() == nil)

                    // UserDefaults
                    Button {
                        clearUserDefaults()
                    } label: {
                        Label("Clear UserDefaults", systemImage: "externaldrive.badge.minus")
                    }
                    .disabled(isGenerating)
                } header: {
                    Label("Resets", systemImage: "arrow.counterclockwise")
                } footer: {
                    Text("Reset local app state. Sign out may be required for changes to take effect.")
                }

                // Danger Zone - Data Deletion
                Section {
                    Button(role: .destructive) {
                        Task {
                            await clearAllFeedback()
                        }
                    } label: {
                        Label("Clear Project Feedback", systemImage: "bubble.left.and.bubble.right")
                    }
                    .disabled(isGenerating || selectedProject == nil)

                    Button(role: .destructive) {
                        Task {
                            await clearAllProjects()
                        }
                    } label: {
                        Label("Delete All My Projects", systemImage: "folder.badge.minus")
                    }
                    .disabled(isGenerating || projectViewModel.projects.isEmpty)
                } header: {
                    Label("Data Deletion", systemImage: "trash")
                        .foregroundStyle(.orange)
                } footer: {
                    Text("Delete server data. This affects the selected project or all your projects.")
                }

                // Full Reset Section (DEBUG only)
                if BuildEnvironment.isDebug {
                    Section {
                        Button(role: .destructive) {
                            showingFullResetConfirmation = true
                        } label: {
                            HStack {
                                Label("Full Database Reset", systemImage: "exclamationmark.triangle.fill")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .disabled(isGenerating)
                    } header: {
                        Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    } footer: {
                        Text("Deletes ALL your data: projects, feedback, comments, and local state. You will be signed out.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Developer Center")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if !isStandaloneWindow {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .overlay {
                if isGenerating {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Generating...")
                                .font(.headline)
                        }
                        .padding(32)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .alert("Result", isPresented: $showingResult, presenting: generationResult) { _ in
                Button("OK") {
                    generationResult = nil
                }
            } message: { result in
                VStack {
                    Text(result.message)
                    if !result.details.isEmpty {
                        Text(result.details.joined(separator: "\n"))
                            .font(.caption)
                    }
                }
            }
            .confirmationDialog(
                "Full Database Reset",
                isPresented: $showingFullResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    Task {
                        await performFullReset()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete ALL your projects, feedback, comments, and reset all local state. You will be signed out. This cannot be undone.")
            }
            .alert(
                "Switch to \(pendingEnvironmentName)?",
                isPresented: $showingEnvironmentChangeConfirmation
            ) {
                Button("Switch", role: .destructive) {
                    if let pending = pendingEnvironment {
                        changeEnvironment(to: pending)
                    }
                    pendingEnvironment = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingEnvironment = nil
                }
            } message: {
                Text("This will sign you out. Auth tokens are environment-specific and cannot be transferred.")
            }
            .task {
                // Auto-select first project if available
                if selectedProject == nil, let first = projectViewModel.projects.first {
                    selectedProject = first
                }
            }
        }
    }

    // MARK: - Generation Functions

    private func generateProjects() async {
        isGenerating = true
        AppLogger.view.info("Generating \(projectCount) dummy projects...")

        var created: [String] = []
        var failed = 0

        for i in 1...projectCount {
            let name = DummyDataGenerator.projectName()
            let description = DummyDataGenerator.projectDescription()

            projectViewModel.newProjectName = name
            projectViewModel.newProjectDescription = description

            let result = await projectViewModel.createProject()
            if case .success = result {
                created.append(name)
                AppLogger.view.info("Created project: \(name)")
            } else {
                failed += 1
                AppLogger.view.error("Failed to create project \(i)")
            }
        }

        isGenerating = false
        generationResult = GenerationResult(
            success: failed == 0,
            message: "Created \(created.count) project(s)" + (failed > 0 ? ", \(failed) failed" : ""),
            details: created
        )
        showingResult = true
    }

    private func generateFeedback() async {
        guard let project = selectedProject else { return }

        isGenerating = true
        AppLogger.view.info("Generating \(feedbackCount) dummy feedback items for project: \(project.name)")

        // Load full project to get API key
        await projectViewModel.loadProject(id: project.id)
        guard let fullProject = projectViewModel.selectedProject else {
            isGenerating = false
            generationResult = GenerationResult(
                success: false,
                message: "Failed to load project details",
                details: []
            )
            showingResult = true
            return
        }

        var created = 0
        var failed = 0

        for _ in 1...feedbackCount {
            do {
                let feedback = DummyDataGenerator.feedback()
                _ = try await AdminAPIClient.shared.createFeedback(
                    title: feedback.title,
                    description: feedback.description,
                    category: feedback.category,
                    userId: feedback.userId,
                    userEmail: feedback.userEmail,
                    apiKey: fullProject.apiKey
                )
                created += 1
            } catch {
                failed += 1
                AppLogger.view.error("Failed to create feedback: \(error.localizedDescription)")
            }
        }

        // Refresh project to update feedback count
        await projectViewModel.loadProjects()

        isGenerating = false
        generationResult = GenerationResult(
            success: failed == 0,
            message: "Created \(created) feedback item(s)" + (failed > 0 ? ", \(failed) failed" : ""),
            details: []
        )
        showingResult = true
    }

    private func generateComments() async {
        guard let project = selectedProject else { return }

        isGenerating = true
        AppLogger.view.info("Generating comments for feedback in project: \(project.name)")

        // Load full project to get API key
        await projectViewModel.loadProject(id: project.id)
        guard let fullProject = projectViewModel.selectedProject else {
            isGenerating = false
            generationResult = GenerationResult(
                success: false,
                message: "Failed to load project details",
                details: []
            )
            showingResult = true
            return
        }

        // Fetch feedbacks for this project
        do {
            let feedbacks = try await AdminAPIClient.shared.getFeedbacks(apiKey: fullProject.apiKey)
            var totalCreated = 0
            var totalFailed = 0

            for feedback in feedbacks {
                for _ in 1...commentCount {
                    do {
                        let comment = DummyDataGenerator.comment()
                        _ = try await AdminAPIClient.shared.createComment(
                            feedbackId: feedback.id,
                            content: comment.content,
                            userId: comment.userId,
                            isAdmin: comment.isAdmin,
                            apiKey: fullProject.apiKey
                        )
                        totalCreated += 1
                    } catch {
                        totalFailed += 1
                    }
                }
            }

            isGenerating = false
            generationResult = GenerationResult(
                success: totalFailed == 0,
                message: "Created \(totalCreated) comment(s) across \(feedbacks.count) feedback item(s)",
                details: totalFailed > 0 ? ["\(totalFailed) failed"] : []
            )
            showingResult = true

        } catch {
            isGenerating = false
            generationResult = GenerationResult(
                success: false,
                message: "Failed to fetch feedback: \(error.localizedDescription)",
                details: []
            )
            showingResult = true
        }
    }

    private func clearAllFeedback() async {
        guard let project = selectedProject else { return }

        isGenerating = true
        AppLogger.view.info("Clearing all feedback for project: \(project.name)")

        // Load full project to get API key
        await projectViewModel.loadProject(id: project.id)
        guard let fullProject = projectViewModel.selectedProject else {
            isGenerating = false
            return
        }

        do {
            let feedbacks = try await AdminAPIClient.shared.getFeedbacks(apiKey: fullProject.apiKey)
            var deleted = 0

            for feedback in feedbacks {
                do {
                    try await AdminAPIClient.shared.delete(path: "feedbacks/\(feedback.id)")
                    deleted += 1
                } catch {
                    AppLogger.view.error("Failed to delete feedback \(feedback.id): \(error.localizedDescription)")
                }
            }

            await projectViewModel.loadProjects()

            isGenerating = false
            generationResult = GenerationResult(
                success: true,
                message: "Deleted \(deleted) feedback item(s)",
                details: []
            )
            showingResult = true

        } catch {
            isGenerating = false
            generationResult = GenerationResult(
                success: false,
                message: "Failed: \(error.localizedDescription)",
                details: []
            )
            showingResult = true
        }
    }

    private func clearAllProjects() async {
        isGenerating = true
        AppLogger.view.info("Deleting all projects...")

        var deleted = 0
        let projectsToDelete = projectViewModel.projects

        for project in projectsToDelete {
            let success = await projectViewModel.deleteProject(id: project.id)
            if success {
                deleted += 1
            }
        }

        isGenerating = false
        generationResult = GenerationResult(
            success: true,
            message: "Deleted \(deleted) project(s)",
            details: []
        )
        showingResult = true
    }

    private func resetOnboarding() {
        OnboardingManager.shared.resetOnboarding()
        generationResult = GenerationResult(
            success: true,
            message: "Onboarding has been reset",
            details: ["Sign out to see the welcome screen again"]
        )
        showingResult = true
    }

    private func clearAuthToken() {
        KeychainService.deleteToken()
        generationResult = GenerationResult(
            success: true,
            message: "Auth token cleared",
            details: ["You will need to sign in again"]
        )
        showingResult = true
    }

    private func clearUserDefaults() {
        // Clear all UserDefaults for this app
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.synchronize()
        }

        generationResult = GenerationResult(
            success: true,
            message: "UserDefaults cleared",
            details: ["All local preferences have been reset"]
        )
        showingResult = true
    }

    private func performFullReset() async {
        isGenerating = true
        AppLogger.view.info("Performing full database reset...")

        var details: [String] = []

        // 1. Delete all projects (which cascades to feedback, comments, etc.)
        let projectsToDelete = projectViewModel.projects
        var deletedProjects = 0
        for project in projectsToDelete {
            let success = await projectViewModel.deleteProject(id: project.id)
            if success {
                deletedProjects += 1
            }
        }
        details.append("Deleted \(deletedProjects) project(s)")

        // 2. Clear local state
        OnboardingManager.shared.resetOnboarding()
        details.append("Reset onboarding")

        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.synchronize()
        }
        details.append("Cleared UserDefaults")

        // 3. Clear auth token (this will trigger sign out)
        KeychainService.deleteToken()
        details.append("Cleared auth token")

        isGenerating = false

        generationResult = GenerationResult(
            success: true,
            message: "Full reset completed",
            details: details + ["App will now sign out..."]
        )
        showingResult = true

        // Dismiss the window after a short delay to let user see the result
        try? await Task.sleep(for: .seconds(2))

        // Close window on macOS
        #if os(macOS)
        if isStandaloneWindow {
            await MainActor.run {
                NSApplication.shared.keyWindow?.close()
            }
        } else {
            dismiss()
        }
        #else
        dismiss()
        #endif
    }

    // MARK: - Feature Access Section

    @ViewBuilder
    private var featureAccessSection: some View {
        Section {
            // Subscription tier picker
            Picker(selection: $selectedPreviewTier) {
                ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                    Text(tier.displayName).tag(tier)
                }
            } label: {
                Label("Subscription Tier", systemImage: "crown.fill")
            }

            // Toggle to test actual tier gating (disable environment override)
            Toggle(isOn: Binding(
                get: { subscriptionService.disableEnvironmentOverrideForTesting },
                set: { subscriptionService.disableEnvironmentOverrideForTesting = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Test Subscription Gating", systemImage: "lock.shield")
                    Text("Disable \"All Features Unlocked\" to test actual tier restrictions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Features for selected tier
            tierFeaturesView

            // Save button
            Button {
                Task {
                    await saveSubscriptionTier()
                }
            } label: {
                HStack {
                    Label("Save Tier Override", systemImage: "square.and.arrow.down")
                    Spacer()
                    if isSavingTier {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isSavingTier || appConfiguration.environment == .production)

            // Error message if save failed
            if let error = tierSaveError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Label("Feature Access", systemImage: "star.fill")
        } footer: {
            if appConfiguration.environment == .production {
                Text("Tier override is disabled in Production. Switch to a non-production environment to test different subscription tiers.")
            } else {
                Text("Save your selected tier to update your account's subscription level for testing purposes.")
            }
        }
    }

    // MARK: - Subscription Simulation Section (DEBUG only)

    #if DEBUG
    private var simulatedTierBinding: Binding<SubscriptionTier?> {
        Binding(
            get: { subscriptionService.simulatedTier },
            set: { subscriptionService.simulatedTier = $0 }
        )
    }

    @ViewBuilder
    private var subscriptionSimulationSection: some View {
        Section {
            Picker("Simulated Tier", selection: simulatedTierBinding) {
                Text("None (Use Actual)").tag(Optional<SubscriptionTier>.none)
                Text("Free").tag(Optional<SubscriptionTier>.some(.free))
                Text("Pro").tag(Optional<SubscriptionTier>.some(.pro))
                Text("Team").tag(Optional<SubscriptionTier>.some(.team))
            }

            if let simulated = subscriptionService.simulatedTier {
                HStack {
                    Text("Currently simulating")
                    Spacer()
                    Text(simulated.displayName)
                        .foregroundStyle(.orange)
                }
            }

            Button("Clear Simulated Tier") {
                subscriptionService.clearSimulatedTier()
            }
            .disabled(subscriptionService.simulatedTier == nil)
        } header: {
            Label("Subscription Simulation", systemImage: "theatermasks")
        } footer: {
            Text("Override the subscription tier for testing. This only affects the client - server still uses actual tier.")
        }
    }
    #endif

    @ViewBuilder
    private var tierFeaturesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            TierFeatureRow(
                text: selectedPreviewTier.maxProjects.map { "\($0) Project\($0 == 1 ? "" : "s")" } ?? "Unlimited Projects",
                included: true
            )
            TierFeatureRow(
                text: selectedPreviewTier.maxFeedbackPerProject.map { "\($0) Feedback per Project" } ?? "Unlimited Feedback",
                included: true
            )
            TierFeatureRow(
                text: "Invite Team Members",
                included: selectedPreviewTier.canInviteMembers
            )
            TierFeatureRow(
                text: "Integrations (Slack, GitHub, etc.)",
                included: selectedPreviewTier.hasIntegrations
            )
            TierFeatureRow(
                text: "Advanced Analytics & MRR",
                included: selectedPreviewTier.hasAdvancedAnalytics
            )
            TierFeatureRow(
                text: "Configurable Statuses",
                included: selectedPreviewTier.hasConfigurableStatuses
            )
        }
        .padding(.vertical, 8)
    }

    private func saveSubscriptionTier() async {
        isSavingTier = true
        tierSaveError = nil

        do {
            let result = try await AdminAPIClient.shared.overrideSubscriptionTier(selectedPreviewTier)
            AppLogger.api.info("✅ Subscription tier overridden to: \(result.tier.displayName)")
        } catch {
            tierSaveError = error.localizedDescription
            AppLogger.api.error("❌ Failed to override subscription tier: \(error.localizedDescription)")
        }

        isSavingTier = false
    }

    // MARK: - Server Environment Functions

    private func changeEnvironment(to newEnvironment: AppEnvironment) {
        appConfiguration.switchTo(newEnvironment)
        connectionTestResult = nil

        Task {
            await AdminAPIClient.shared.updateBaseURL()
            AppLogger.api.info("Changed server environment to: \(newEnvironment.displayName)")
            AppLogger.api.info("AdminAPIClient now pointing to: \(newEnvironment.baseURL)")
            // The environmentDidChange notification triggers logout in RootView
            // Dismiss the Developer Center so the user sees the logout
            dismiss()
        }
    }

    private func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil
        AppLogger.api.info("Testing connection to: \(appConfiguration.baseURL)")

        do {
            let success = try await AdminAPIClient.shared.testConnection()
            if success {
                connectionTestResult = "✅ Connected successfully"
                AppLogger.api.info("Connection test successful")
            } else {
                connectionTestResult = "❌ Connection failed"
                AppLogger.api.error("Connection test failed")
            }
        } catch {
            connectionTestResult = "❌ Error: \(error.localizedDescription)"
            AppLogger.api.error("Connection test error: \(error.localizedDescription)")
        }

        isTestingConnection = false
    }
}

// MARK: - Tier Feature Row

private struct TierFeatureRow: View {
    let text: String
    let included: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(included ? .green : .secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(included ? .primary : .secondary)
        }
    }
}

// MARK: - Dummy Data Generator

enum DummyDataGenerator {
    private static let projectNames = [
        "Acme Mobile App", "Phoenix Dashboard", "Nebula Analytics",
        "Quantum CRM", "Atlas Inventory", "Horizon E-commerce",
        "Stellar Support", "Nova Marketplace", "Zenith Scheduler",
        "Echo Messenger", "Pulse Fitness", "Apex Finance"
    ]

    private static let projectDescriptions = [
        "A modern mobile application for managing daily tasks and productivity.",
        "Real-time analytics dashboard with customizable widgets.",
        "Customer relationship management system for small businesses.",
        "Inventory tracking and management solution.",
        "Full-featured e-commerce platform.",
        "Customer support ticketing system.",
        "Online marketplace for digital products.",
        "Team scheduling and coordination app.",
        "Secure messaging application with end-to-end encryption.",
        "Health and fitness tracking companion."
    ]

    private static let feedbackTitles = [
        "Add dark mode support",
        "Improve loading performance",
        "Fix crash on startup",
        "Add export to PDF feature",
        "Support for multiple languages",
        "Better notification settings",
        "Add biometric authentication",
        "Improve search functionality",
        "Add offline mode support",
        "Fix login issues on iOS 18",
        "Add widget support",
        "Improve accessibility features",
        "Add keyboard shortcuts",
        "Support for custom themes",
        "Add data backup feature"
    ]

    private static let feedbackDescriptions = [
        "It would be great to have a dark mode option. The current bright theme is hard on the eyes when using the app at night.",
        "The app takes too long to load the main screen. Can we optimize this for better user experience?",
        "The app crashes immediately after opening on my iPhone 15 Pro. This started happening after the last update.",
        "I need to share reports with my team. Please add an option to export data to PDF format.",
        "Our team is international. Adding support for Spanish, French, and German would be very helpful.",
        "The notification settings are confusing. Can we have more granular control over what triggers notifications?",
        "For security, it would be great to log in using Face ID or Touch ID instead of typing a password every time.",
        "The search feature doesn't find items that are slightly misspelled. Fuzzy search would be helpful.",
        "I often work in areas with poor connectivity. Please add the ability to work offline and sync later.",
        "Since updating to iOS 18, I can't log in. The button just doesn't respond.",
        "Home screen widgets would be amazing for quick access to important information.",
        "Please improve VoiceOver support. Some buttons are not labeled correctly.",
        "Power users would benefit from keyboard shortcuts for common actions.",
        "Let us customize the app's color scheme to match our company branding.",
        "I'm worried about losing my data. Please add automatic cloud backup."
    ]

    private static let commentContents = [
        "Thanks for the feedback! We're looking into this.",
        "This is a great suggestion. Added to our roadmap.",
        "Can you provide more details about your use case?",
        "We've identified the issue and a fix is coming in the next release.",
        "This feature is now available in version 2.1!",
        "We appreciate your patience while we work on this.",
        "Could you try clearing the app cache and see if that helps?",
        "This is currently not supported, but we're considering it for future updates.",
        "We've reproduced the issue and are working on a solution.",
        "Thank you for reporting this bug!",
        "I'm also experiencing this issue. Hope it gets fixed soon.",
        "This would be really useful for my workflow.",
        "+1 for this feature request!",
        "Has there been any progress on this?",
        "The workaround suggested worked for me. Thanks!"
    ]

    private static let userNames = [
        "john_doe", "jane_smith", "mike_wilson", "sarah_connor",
        "alex_chen", "emma_watson", "david_lee", "lisa_wong",
        "chris_martin", "amy_taylor", "user_12345", "feedback_user"
    ]

    private static let emailDomains = [
        "gmail.com", "outlook.com", "yahoo.com", "company.com",
        "example.org", "mail.com", "work.io", "business.net"
    ]

    static func projectName() -> String {
        let adjectives = ["New", "Updated", "Beta", "Test", "Demo"]
        let baseName = projectNames.randomElement() ?? "Test Project"
        let useAdjective = Bool.random()
        return useAdjective ? "\(adjectives.randomElement()!) \(baseName)" : baseName
    }

    static func projectDescription() -> String {
        projectDescriptions.randomElement() ?? "A test project for development purposes."
    }

    static func feedback() -> (title: String, description: String, category: FeedbackCategory, userId: String, userEmail: String) {
        let title = feedbackTitles.randomElement() ?? "Test Feedback"
        let description = feedbackDescriptions.randomElement() ?? "This is a test feedback item."
        let category = FeedbackCategory.allCases.randomElement() ?? .other
        let userId = userNames.randomElement() ?? "test_user"
        let domain = emailDomains.randomElement() ?? "example.com"
        let email = "\(userId)@\(domain)"

        return (title, description, category, userId, email)
    }

    static func comment() -> (content: String, userId: String, isAdmin: Bool) {
        let content = commentContents.randomElement() ?? "This is a test comment."
        let isAdmin = Bool.random() && Bool.random() // 25% chance of being admin
        let userId = isAdmin ? "admin" : (userNames.randomElement() ?? "test_user")

        return (content, userId, isAdmin)
    }
}

// MARK: - Preview

#Preview("Developer Center") {
    DeveloperCenterView(projectViewModel: ProjectViewModel())
}
