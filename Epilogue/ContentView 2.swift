import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var libraryViewModel = LibraryViewModel()
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.02, green: 0.02, blue: 0.15)
                .ignoresSafeArea()
            
            // Main content based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    NavigationStack {
                        LibraryView()
                    }
                case 1:
                    NavigationStack {
                        NotesView()
                    }
                case 2:
                    NavigationStack {
                        ChatView()
                    }
                default:
                    EmptyView()
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom) // Allow content to extend under
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Universal command bar with proper glass blur
            UniversalCommandBar(selectedTab: $selectedTab)
        }
        .environmentObject(libraryViewModel)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
