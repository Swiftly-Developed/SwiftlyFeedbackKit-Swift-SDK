import SwiftUI
import SwiftlyFeedbackKit

// MARK: - Environment Indicator

/// A compact indicator showing the current environment for non-production builds
struct EnvironmentIndicator: View {
    @State private var appConfiguration = AppConfiguration.shared

    var body: some View {
        if appConfiguration.environment != .production {
            HStack(spacing: 4) {
                Circle()
                    .fill(appConfiguration.environment.color)
                    .frame(width: 6, height: 6)
                Text(appConfiguration.environment.displayName.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(appConfiguration.environment.color.opacity(0.15))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var projectViewModel = ProjectViewModel()
    @State private var homeDashboardViewModel = HomeDashboardViewModel()
    @State private var hasLoadedProjects = false
    @Environment(DeepLinkManager.self) private var deepLinkManager

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
    @Environment(DeepLinkManager.self) private var deepLinkManager
    @State private var selectedTab: Tab = .home

    enum Tab: Hashable {
        case home, projects, feedback, users, events, featureRequests, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SwiftUI.Tab("Home", systemImage: "house", value: Tab.home) {
                NavigationStack {
                    HomeDashboardView(viewModel: homeDashboardViewModel)
                }
            }

            SwiftUI.Tab("Projects", systemImage: "folder", value: Tab.projects) {
                NavigationStack {
                    ProjectListView(viewModel: projectViewModel)
                }
            }

            SwiftUI.Tab("Feedback", systemImage: "bubble.left.and.bubble.right", value: Tab.feedback) {
                NavigationStack {
                    FeedbackDashboardView(projectViewModel: projectViewModel)
                }
            }

            SwiftUI.Tab("Users", systemImage: "person.2", value: Tab.users) {
                NavigationStack {
                    UsersDashboardView(projectViewModel: projectViewModel)
                }
            }

            SwiftUI.Tab("Events", systemImage: "chart.bar.xaxis", value: Tab.events) {
                NavigationStack {
                    EventsDashboardView(projectViewModel: projectViewModel)
                }
            }

            // Feature Requests - uses SwiftlyFeedbackKit
            SwiftUI.Tab("Feature Requests", systemImage: "lightbulb", value: Tab.featureRequests) {
                SwiftlyFeedbackKit.FeedbackListView()
            }

            SwiftUI.Tab("Settings", systemImage: "gear", value: Tab.settings) {
                NavigationStack {
                    SettingsView(authViewModel: authViewModel, projectViewModel: projectViewModel)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onChange(of: deepLinkManager.pendingDestination) { _, destination in
            handleDeepLink(destination)
        }
        .onAppear {
            // Handle deep link if app was launched via URL
            handleDeepLink(deepLinkManager.pendingDestination)
        }
    }

    private func handleDeepLink(_ destination: DeepLinkDestination?) {
        guard let destination else { return }

        switch destination {
        case .settings, .settingsNotifications:
            selectedTab = .settings
        }

        deepLinkManager.clearPendingDestination()
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
    @Environment(DeepLinkManager.self) private var deepLinkManager

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
        .onChange(of: deepLinkManager.pendingDestination) { _, destination in
            handleDeepLink(destination)
        }
        .onAppear {
            // Handle deep link if app was launched via URL
            handleDeepLink(deepLinkManager.pendingDestination)
        }
    }

    private func handleDeepLink(_ destination: DeepLinkDestination?) {
        guard let destination else { return }

        switch destination {
        case .settings, .settingsNotifications:
            selectedSection = .settings
        }

        deepLinkManager.clearPendingDestination()
    }
}
#endif

#Preview {
    MainTabView(authViewModel: AuthViewModel())
}
