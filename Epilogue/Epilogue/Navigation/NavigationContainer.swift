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
                Label {
                    Text("Library")
                } icon: {
                    Image(themeManager.currentTheme.libraryIcon)
                        .renderingMode(.template)
                }
            }
            .tag(0)

            NavigationStack {
                CleanNotesView()
            }
            .tabItem {
                Label {
                    Text("Notes")
                } icon: {
                    Image(themeManager.currentTheme.notesIcon)
                        .renderingMode(.template)
                }
            }
            .tag(1)

            ChatViewWrapper()
            .tabItem {
                Label {
                    Text("Sessions")
                } icon: {
                    Image(themeManager.currentTheme.sessionsIcon)
                        .renderingMode(.template)
                }
            }
            .tag(2)
        }
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

        // Use the theme's primary accent color for active icons
        appearance.tintColor = UIColor(themeManager.currentTheme.primaryAccent)
        // Revert to fixed inactive gray for consistency with prior look
        appearance.unselectedItemTintColor = UIColor(white: 0.5, alpha: 1.0)
    }

    private func updateTabBarAppearance() {
        // Update colors based on current theme
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
