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
                    Image(selectedTab == 0 ? "book-active" : "book-inactive")
                        .renderingMode(.original)
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
                    Image(selectedTab == 1 ? "feather-active" : "feather-inactive")
                        .renderingMode(.original)
                }
            }
            .tag(1)

            ChatViewWrapper()
            .tabItem {
                Label {
                    Text("Sessions")
                } icon: {
                    Image(selectedTab == 2 ? "msgs-active" : "msgs-inactive")
                        .renderingMode(.original)
                }
            }
            .tag(2)
        }
        // Don't apply tint since we're using original rendering mode
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

        // Don't set tint colors since we're using original rendering for PDF icons
        appearance.tintColor = nil
        appearance.unselectedItemTintColor = nil
    }

    private func updateTabBarAppearance() {
        // Don't override icon colors for PDFs with original rendering
        UITabBar.appearance().tintColor = nil
        UITabBar.appearance().unselectedItemTintColor = nil
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
