import SwiftUI

struct MainTabView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var projectViewModel = ProjectViewModel()
    @State private var homeDashboardViewModel = HomeDashboardViewModel()
    @State private var hasLoadedProjects = false

    var body: some View {
        #if os(macOS)
        MacNavigationView(authViewModel: authViewModel, projectViewModel: projectViewModel, homeDashboardViewModel: homeDashboardViewModel)
            .task {
                await loadProjectsOnce()
            }
        #else
        TabView {
            NavigationStack {
                HomeDashboardView(viewModel: homeDashboardViewModel)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

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
                EventsDashboardView(projectViewModel: projectViewModel)
            }
            .tabItem {
                Label("Events", systemImage: "chart.bar.xaxis")
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
    @Bindable var homeDashboardViewModel: HomeDashboardViewModel
    @State private var selectedSection: SidebarSection? = .home

    enum SidebarSection: String, CaseIterable, Identifiable {
        case home = "Home"
        case projects = "Projects"
        case feedback = "Feedback"
        case users = "Users"
        case events = "Events"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house"
            case .projects: return "folder"
            case .feedback: return "bubble.left.and.bubble.right"
            case .users: return "person.2"
            case .events: return "chart.bar.xaxis"
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
            case .home:
                NavigationStack {
                    HomeDashboardView(viewModel: homeDashboardViewModel)
                }
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
            case .events:
                NavigationStack {
                    EventsDashboardView(projectViewModel: projectViewModel)
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
