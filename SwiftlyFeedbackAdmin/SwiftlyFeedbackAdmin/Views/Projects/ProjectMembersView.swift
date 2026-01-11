import SwiftUI

struct ProjectMembersView: View {
    let projectId: UUID
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var showingAddMember = false
    @State private var showingPaywall = false
    @State private var forceShowPaywall = false  // True when triggered by server 402
    @State private var shouldRetryAddMemberAfterPaywall = false  // Re-open add member sheet after successful paywall
    @State private var subscriptionService = SubscriptionService.shared

    var body: some View {
        NavigationStack {
            List {
                if viewModel.projectMembers.isEmpty && viewModel.pendingInvites.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No Members", systemImage: "person.2")
                        } description: {
                            Text("Add team members to collaborate on this project")
                        }
                    }
                } else {
                    if !viewModel.projectMembers.isEmpty {
                        Section("Team Members") {
                            ForEach(viewModel.projectMembers) { member in
                                MemberRowView(
                                    member: member,
                                    onRoleChange: { newRole in
                                        Task {
                                            await viewModel.updateMemberRole(
                                                projectId: projectId,
                                                memberId: member.id,
                                                role: newRole
                                            )
                                        }
                                    },
                                    onRemove: {
                                        Task {
                                            await viewModel.removeMember(
                                                projectId: projectId,
                                                memberId: member.id
                                            )
                                        }
                                    }
                                )
                            }
                        }
                    }

                    if !viewModel.pendingInvites.isEmpty {
                        Section("Pending Invites") {
                            ForEach(viewModel.pendingInvites) { invite in
                                InviteRowView(
                                    invite: invite,
                                    onResend: {
                                        Task {
                                            await viewModel.resendInvite(
                                                projectId: projectId,
                                                inviteId: invite.id
                                            )
                                        }
                                    },
                                    onCancel: {
                                        Task {
                                            await viewModel.cancelInvite(
                                                projectId: projectId,
                                                inviteId: invite.id
                                            )
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Members")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if subscriptionService.meetsRequirement(.team) {
                            showingAddMember = true
                        } else {
                            forceShowPaywall = false  // User clicked button, show environment override if applicable
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .tierBadge(.team)
                    }
                }
            }
            .sheet(isPresented: $showingAddMember, onDismiss: {
                // Check if paywall needs to be shown after dismissing add member sheet
                if viewModel.shouldShowPaywallAfterAddMember {
                    viewModel.shouldShowPaywallAfterAddMember = false
                    forceShowPaywall = true  // Server returned 402, force actual paywall
                    shouldRetryAddMemberAfterPaywall = true  // Remember to re-open add member after paywall
                    showingPaywall = true
                }
            }) {
                AddMemberSheet(projectId: projectId, viewModel: viewModel)
                    #if os(macOS)
                    .frame(minWidth: 400, minHeight: 350)
                    #endif
            }
            .sheet(isPresented: $showingPaywall, onDismiss: {
                // After paywall dismisses, re-open add member sheet if we were trying to add a member
                // The email/role are still in the viewModel, so user can just click Add
                if shouldRetryAddMemberAfterPaywall {
                    shouldRetryAddMemberAfterPaywall = false
                    // Small delay to ensure the sheet transition is smooth
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingAddMember = true
                    }
                }
            }) {
                PaywallView(requiredTier: .team, forceShowPaywall: forceShowPaywall)
            }
            .task {
                await viewModel.loadMembers(projectId: projectId)
                await viewModel.loadInvites(projectId: projectId)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }
}

struct InviteRowView: View {
    let invite: ProjectInvite
    let onResend: () -> Void
    let onCancel: () -> Void

    @State private var showingCancelAlert = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(invite.email)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(invite.role.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Expires \(invite.expiresAt, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                Button {
                    onResend()
                } label: {
                    Label("Resend Invite", systemImage: "envelope.arrow.triangle.branch")
                }

                Divider()

                Button(role: .destructive) {
                    showingCancelAlert = true
                } label: {
                    Label("Cancel Invite", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .alert("Cancel Invite", isPresented: $showingCancelAlert) {
            Button("Keep", role: .cancel) {}
            Button("Cancel Invite", role: .destructive) {
                onCancel()
            }
        } message: {
            Text("Are you sure you want to cancel the invitation to \(invite.email)?")
        }
    }
}

struct MemberRowView: View {
    let member: ProjectMember
    let onRoleChange: (ProjectRole) -> Void
    let onRemove: () -> Void

    @State private var showingRemoveAlert = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(member.userName)
                    .font(.headline)
                Text(member.userEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                ForEach(ProjectRole.allCases, id: \.self) { role in
                    Button {
                        if role != member.role {
                            onRoleChange(role)
                        }
                    } label: {
                        HStack {
                            Text(role.displayName)
                            if role == member.role {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button(role: .destructive) {
                    showingRemoveAlert = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                HStack {
                    Text(member.role.displayName)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .alert("Remove Member", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Are you sure you want to remove \(member.userName) from this project?")
        }
    }
}

struct AddMemberSheet: View {
    let projectId: UUID
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email Address", text: $viewModel.newMemberEmail)
                        .focused($isEmailFocused)
                        .textContentType(.emailAddress)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif

                    Picker("Role", selection: $viewModel.newMemberRole) {
                        ForEach(ProjectRole.allCases, id: \.self) { role in
                            Text(role.displayName)
                                .tag(role)
                        }
                    }
                } header: {
                    Text("Member Details")
                } footer: {
                    Text("If the user doesn't have an account, an invitation email will be sent.")
                }

                Section {
                    ForEach(ProjectRole.allCases, id: \.self) { role in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(role.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(role.roleDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Role Descriptions")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Member")
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
                    Button("Add") {
                        Task {
                            let result = await viewModel.addMember(projectId: projectId)
                            switch result {
                            case .success:
                                dismiss()
                            case .paymentRequired:
                                // Set flag to show paywall after this sheet dismisses
                                viewModel.shouldShowPaywallAfterAddMember = true
                                dismiss()
                            case .otherError:
                                break // Error alert will be shown by viewModel.showError
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.newMemberEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
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
            .onAppear {
                isEmailFocused = true
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
}

#Preview {
    ProjectMembersView(projectId: UUID(), viewModel: ProjectViewModel())
}
