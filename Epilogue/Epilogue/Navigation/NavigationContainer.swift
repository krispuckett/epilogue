import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "Navigation")

/// Focused component for tab bar navigation
struct NavigationContainer: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label {
                    Text("Library")
                } icon: {
                    Image("glass-book-open")
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
                    Image("glass-feather")
                        .renderingMode(.original)
                }
            }
            .tag(1)

            ChatViewWrapper()
            .tabItem {
                Label {
                    Text("Chat")
                } icon: {
                    Image("glass-msgs")
                        .renderingMode(.original)
                }
            }
            .tag(2)
        }
        .tint(DesignSystem.Colors.primaryAccent)
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