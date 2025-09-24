import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "Navigation")

/// Focused component for tab bar navigation
struct NavigationContainer: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Image(selectedTab == 0 ? "book-active" : "book-inactive")
                    .renderingMode(.original)
                Text("Library")
            }
            .tag(0)

            NavigationStack {
                CleanNotesView()
            }
            .tabItem {
                Image(selectedTab == 1 ? "feather-active" : "feather-inactive")
                    .renderingMode(.original)
                Text("Notes")
            }
            .tag(1)

            ChatViewWrapper()
            .tabItem {
                Image(selectedTab == 2 ? "msgs-active" : "msgs-inactive")
                    .renderingMode(.original)
                Text("Sessions")
            }
            .tag(2)
        }
        // Apply tint for text labels only (icons use original rendering)
        .tint(themeManager.currentTheme.primaryAccent)
        .onAppear {
            // Restore original tab bar with proper glass effect
            setupTabBarAppearance()
        }
        .environmentObject(libraryViewModel)
        .environmentObject(notesViewModel)
        .environmentObject(navigationCoordinator)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onChange(of: selectedTab) { oldValue, newValue in
            logger.debug("Tab changed from \(oldValue) to \(newValue)")
            syncWithNavigationCoordinator(newValue)
        }
        .onChange(of: navigationCoordinator.selectedTab) { _, newValue in
            syncFromNavigationCoordinator(newValue)
        }
        .onChange(of: themeManager.currentTheme) { _, _ in
            // Update tab bar colors when theme changes
            updateTabBarAppearance()
        }
    }

    private func setupTabBarAppearance() {
        // Use default system appearance for proper blur
        let appearance = UITabBar.appearance()
        appearance.backgroundImage = nil
        appearance.shadowImage = nil
        appearance.isTranslucent = true

        // Don't use UITabBarAppearance - let system handle the blur
        appearance.backgroundColor = nil
        appearance.barTintColor = nil

        // Set tint color for text labels (icons preserve their original colors)
        appearance.tintColor = UIColor(themeManager.currentTheme.primaryAccent)
        appearance.unselectedItemTintColor = UIColor(white: 0.5, alpha: 1.0)
    }

    private func updateTabBarAppearance() {
        // Update text colors while preserving icon colors
        UITabBar.appearance().tintColor = UIColor(themeManager.currentTheme.primaryAccent)
        UITabBar.appearance().unselectedItemTintColor = UIColor(white: 0.5, alpha: 1.0)
    }

    private func syncWithNavigationCoordinator(_ tab: Int) {
        switch tab {
        case 0: navigationCoordinator.selectedTab = .library
        case 1: navigationCoordinator.selectedTab = .notes
        case 2: navigationCoordinator.selectedTab = .chat
        default: break
        }
    }

    private func syncFromNavigationCoordinator(_ tab: NavigationCoordinator.TabItem) {
        switch tab {
        case .library: selectedTab = 0
        case .notes: selectedTab = 1
        case .chat: selectedTab = 2
        }
    }
}
