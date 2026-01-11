import SwiftUI

struct SlackSettingsView: View {
    let project: Project
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var webhookURL: String
    @State private var notifyNewFeedback: Bool
    @State private var notifyNewComments: Bool
    @State private var notifyStatusChanges: Bool
    @State private var isActive: Bool
    @State private var showPaywall = false

    init(project: Project, viewModel: ProjectViewModel) {
        self.project = project
        self.viewModel = viewModel
        _webhookURL = State(initialValue: project.slackWebhookUrl ?? "")
        _notifyNewFeedback = State(initialValue: project.slackNotifyNewFeedback)
        _notifyNewComments = State(initialValue: project.slackNotifyNewComments)
        _notifyStatusChanges = State(initialValue: project.slackNotifyStatusChanges)
        _isActive = State(initialValue: project.slackIsActive)
    }

    private var hasChanges: Bool {
        webhookURL != (project.slackWebhookUrl ?? "") ||
        notifyNewFeedback != project.slackNotifyNewFeedback ||
        notifyNewComments != project.slackNotifyNewComments ||
        notifyStatusChanges != project.slackNotifyStatusChanges ||
        isActive != project.slackIsActive
    }

    private var isWebhookConfigured: Bool {
        !webhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if isWebhookConfigured {
                    Section {
                        Toggle("Integration Active", isOn: $isActive)
                    } footer: {
                        Text("When disabled, no Slack notifications will be sent even if configured.")
                    }
                }

                Section {
                    TextEditor(text: $webhookURL)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                        .scrollContentBackground(.hidden)

                    Text("Get a webhook URL from your Slack workspace: **Apps & Integrations** > **Incoming Webhooks**")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Slack Webhook", systemImage: "number")
                } footer: {
                    if !webhookURL.isEmpty && !webhookURL.hasPrefix("https://hooks.slack.com/") {
                        Text("Webhook URL must start with https://hooks.slack.com/")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Toggle("New feedback submitted", isOn: $notifyNewFeedback)
                    Toggle("New comments", isOn: $notifyNewComments)
                    Toggle("Status changes", isOn: $notifyStatusChanges)
                } header: {
                    Text("Send notifications for")
                } footer: {
                    if !isWebhookConfigured {
                        Text("Configure a webhook URL above to enable Slack notifications")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!isWebhookConfigured)

                if isWebhookConfigured {
                    Section {
                        Button(role: .destructive) {
                            webhookURL = ""
                        } label: {
                            Label("Remove Slack Integration", systemImage: "trash")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Slack Integration")
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
                    .disabled(!hasChanges || viewModel.isLoading || (!webhookURL.isEmpty && !webhookURL.hasPrefix("https://hooks.slack.com/")))
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
            .sheet(isPresented: $showPaywall) {
                PaywallView(requiredTier: .pro, forceShowPaywall: true)
            }
        }
    }

    private func saveSettings() {
        Task {
            let trimmedURL = webhookURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = await viewModel.updateSlackSettings(
                projectId: project.id,
                slackWebhookUrl: trimmedURL.isEmpty ? "" : trimmedURL,
                slackNotifyNewFeedback: notifyNewFeedback,
                slackNotifyNewComments: notifyNewComments,
                slackNotifyStatusChanges: notifyStatusChanges,
                slackIsActive: isActive
            )
            switch result {
            case .success:
                dismiss()
            case .paymentRequired:
                showPaywall = true
            case .otherError:
                break
            }
        }
    }
}

#Preview {
    SlackSettingsView(
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
            slackIsActive: true,
            allowedStatuses: ["pending", "approved", "in_progress", "completed", "rejected"]
        ),
        viewModel: ProjectViewModel()
    )
}
