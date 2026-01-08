import SwiftUI
import SwiftlyFeedbackKit

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
        iOSTabView(authViewModel: authViewModel, projectViewModel: projectViewModel, homeDashboardViewModel: homeDashboardViewModel)
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

// MARK: - iOS/iPadOS Tab View

#if !os(macOS)
struct iOSTabView: View {
    @Bindable var authViewModel: AuthViewModel
    @Bindable var projectViewModel: ProjectViewModel
    @Bindable var homeDashboardViewModel: HomeDashboardViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    HomeDashboardView(viewModel: homeDashboardViewModel)
                }
            }

            Tab("Projects", systemImage: "folder") {
                NavigationStack {
                    ProjectListView(viewModel: projectViewModel)
                }
            }

            Tab("Feedback", systemImage: "bubble.left.and.bubble.right") {
                NavigationStack {
                    FeedbackDashboardView(projectViewModel: projectViewModel)
                }
            }

            Tab("Users", systemImage: "person.2") {
                NavigationStack {
                    UsersDashboardView(projectViewModel: projectViewModel)
                }
            }

            Tab("Events", systemImage: "chart.bar.xaxis") {
                NavigationStack {
                    EventsDashboardView(projectViewModel: projectViewModel)
                }
            }

            // Feature Requests - uses SwiftlyFeedbackKit
            Tab("Feature Requests", systemImage: "lightbulb") {
                SwiftlyFeedbackKit.FeedbackListView()
            }

            Tab("Settings", systemImage: "gear") {
                NavigationStack {
                    SettingsView(authViewModel: authViewModel, projectViewModel: projectViewModel)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
#endif

// MARK: - macOS Navigation View

#if os(macOS)
struct MacNavigationView: View {
    @Bindable var authViewModel: AuthViewModel
    @Bindable var projectViewModel: ProjectViewModel
    @Bindable var homeDashboardViewModel: HomeDashboardViewModel
    @State private var selectedSection: SidebarSection? = .home

    enum SidebarSection: String, Identifiable {
        case home = "Home"
        case projects = "Projects"
        case feedback = "Feedback"
        case users = "Users"
        case events = "Events"
        case featureRequests = "Feature Requests"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house"
            case .projects: return "folder"
            case .feedback: return "bubble.left.and.bubble.right"
            case .users: return "person.2"
            case .events: return "chart.bar.xaxis"
            case .featureRequests: return "lightbulb"
            case .settings: return "gear"
            }
        }

        /// Main sections (appear at the top)
        static var mainSections: [SidebarSection] {
            [.home, .projects, .feedback, .users, .events]
        }

        /// Bottom sections (appear after spacer and divider)
        static var bottomSections: [SidebarSection] {
            [.featureRequests, .settings]
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedSection) {
                    // Main sections
                    ForEach(SidebarSection.mainSections, id: \.id) { section in
                        Label(section.rawValue, systemImage: section.icon)
                            .tag(section)
                    }
                }
                .listStyle(.sidebar)

                Spacer()

                Divider()

                // Bottom sections (Try SDK + Settings)
                List(selection: $selectedSection) {
                    ForEach(SidebarSection.bottomSections, id: \.id) { section in
                        Label(section.rawValue, systemImage: section.icon)
                            .tag(section)
                    }
                }
                .listStyle(.sidebar)
                .frame(height: 80)
            }
            .navigationTitle("Feedback Kit")
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
            case .featureRequests:
                SwiftlyFeedbackKit.FeedbackListView()
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
