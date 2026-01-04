import SwiftUI

struct StatusSettingsView: View {
    let project: Project
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var enabledStatuses: Set<FeedbackStatus>

    init(project: Project, viewModel: ProjectViewModel) {
        self.project = project
        self.viewModel = viewModel
        // Initialize with the project's allowed statuses
        let allowedStatusSet = Set(project.allowedStatuses.compactMap { FeedbackStatus(rawValue: $0) })
        _enabledStatuses = State(initialValue: allowedStatusSet)
    }

    private var hasChanges: Bool {
        let currentStatuses = Set(project.allowedStatuses.compactMap { FeedbackStatus(rawValue: $0) })
        return enabledStatuses != currentStatuses
    }

    /// Statuses that can be toggled on/off (pending is always required)
    private var optionalStatuses: [FeedbackStatus] {
        FeedbackStatus.allCases.filter { $0 != .pending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose which statuses are available for feedback in this project. Disabled statuses won't appear in status menus or the Kanban board.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Required") {
                    HStack {
                        StatusRow(status: .pending)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundStyle(.secondary)
                    }
                    .opacity(0.6)
                }

                Section("Optional Statuses") {
                    ForEach(optionalStatuses, id: \.self) { status in
                        Toggle(isOn: binding(for: status)) {
                            StatusRow(status: status)
                        }
                        .tint(statusColor(for: status))
                    }
                }

                Section {
                    Button("Reset to Default") {
                        enabledStatuses = Set(FeedbackStatus.defaultAllowed)
                    }
                    .disabled(!hasChanges && enabledStatuses == Set(FeedbackStatus.defaultAllowed))
                } footer: {
                    Text("Default statuses: Pending, Approved, In Progress, Completed, Rejected")
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Status Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges || viewModel.isLoading)
                }
            }
            .interactiveDismissDisabled(viewModel.isLoading)
            .overlay {
                if viewModel.isLoading {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }

    private func binding(for status: FeedbackStatus) -> Binding<Bool> {
        Binding(
            get: { enabledStatuses.contains(status) },
            set: { isEnabled in
                if isEnabled {
                    enabledStatuses.insert(status)
                } else {
                    enabledStatuses.remove(status)
                }
            }
        )
    }

    private func statusColor(for status: FeedbackStatus) -> Color {
        switch status.color {
        case "gray": return .gray
        case "blue": return .blue
        case "orange": return .orange
        case "cyan": return .cyan
        case "green": return .green
        case "red": return .red
        default: return .primary
        }
    }

    private func saveSettings() {
        Task {
            // Always include pending, plus any other enabled statuses
            var allStatuses = enabledStatuses
            allStatuses.insert(.pending)

            let statusStrings = allStatuses.map { $0.rawValue }
            let success = await viewModel.updateAllowedStatuses(
                projectId: project.id,
                allowedStatuses: statusStrings
            )
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Status Row

private struct StatusRow: View {
    let status: FeedbackStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.icon)
                .foregroundStyle(statusColor)
                .frame(width: 24)
            Text(status.displayName)
        }
    }

    private var statusColor: Color {
        switch status.color {
        case "gray": return .gray
        case "blue": return .blue
        case "orange": return .orange
        case "cyan": return .cyan
        case "green": return .green
        case "red": return .red
        default: return .primary
        }
    }
}

// MARK: - FeedbackStatus Extension

extension FeedbackStatus {
    /// Default statuses enabled for new projects
    static var defaultAllowed: [FeedbackStatus] {
        [.pending, .approved, .inProgress, .completed, .rejected]
    }
}

#Preview {
    StatusSettingsView(
        project: Project(
            id: UUID(),
            name: "Test Project",
            apiKey: "test-api-key",
            description: "A test description",
            ownerId: UUID(),
            ownerEmail: "test@example.com",
            isArchived: false,
            archivedAt: nil,
            colorIndex: 0,
            feedbackCount: 42,
            memberCount: 5,
            createdAt: Date(),
            updatedAt: Date(),
            slackWebhookUrl: nil,
            slackNotifyNewFeedback: true,
            slackNotifyNewComments: true,
            slackNotifyStatusChanges: true,
            allowedStatuses: ["pending", "approved", "in_progress", "completed", "rejected"]
        ),
        viewModel: ProjectViewModel()
    )
}
