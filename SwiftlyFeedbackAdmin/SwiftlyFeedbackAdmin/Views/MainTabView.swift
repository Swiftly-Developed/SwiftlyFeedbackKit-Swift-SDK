import SwiftUI

struct MainTabView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var projectViewModel = ProjectViewModel()
    @State private var hasLoadedProjects = false

    var body: some View {
        #if os(macOS)
        MacNavigationView(authViewModel: authViewModel, projectViewModel: projectViewModel)
            .task {
                await loadProjectsOnce()
            }
        #else
        TabView {
            NavigationStack {
                ProjectListView(viewModel: projectViewModel)
            }
            .tabItem {
                Label("Projects", systemImage: "folder")
            }

            NavigationStack {
                FeedbackDashboardView(projectViewModel: projectViewModel)
            }
            .tabItem {
                Label("Feedback", systemImage: "bubble.left.and.bubble.right")
            }

            NavigationStack {
                UsersDashboardView(projectViewModel: projectViewModel)
            }
            .tabItem {
                Label("Users", systemImage: "person.2")
            }

            NavigationStack {
                SettingsView(authViewModel: authViewModel, projectViewModel: projectViewModel)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .task {
            await loadProjectsOnce()
        }
        #endif
    }

    private func loadProjectsOnce() async {
        guard !hasLoadedProjects else { return }
        hasLoadedProjects = true
        await projectViewModel.loadProjects()
    }
}

// MARK: - macOS Navigation View

#if os(macOS)
struct MacNavigationView: View {
    @Bindable var authViewModel: AuthViewModel
    @Bindable var projectViewModel: ProjectViewModel
    @State private var selectedSection: SidebarSection? = .projects

    enum SidebarSection: String, CaseIterable, Identifiable {
        case projects = "Projects"
        case feedback = "Feedback"
        case users = "Users"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .projects: return "folder"
            case .feedback: return "bubble.left.and.bubble.right"
            case .users: return "person.2"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("SwiftlyFeedback")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            switch selectedSection {
            case .projects:
                NavigationStack {
                    ProjectListView(viewModel: projectViewModel)
                }
            case .feedback:
                NavigationStack {
                    FeedbackDashboardView(projectViewModel: projectViewModel)
                }
            case .users:
                NavigationStack {
                    UsersDashboardView(projectViewModel: projectViewModel)
                }
            case .settings:
                NavigationStack {
                    SettingsView(authViewModel: authViewModel, projectViewModel: projectViewModel)
                }
            case nil:
                ContentUnavailableView("Select a Section", systemImage: "sidebar.left", description: Text("Choose a section from the sidebar"))
            }
        }
    }
}
#endif

#Preview {
    MainTabView(authViewModel: AuthViewModel())
}
