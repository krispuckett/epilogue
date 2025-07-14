import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    
    init() {
        print("🏠 DEBUG: ContentView init")
    }
    
    var body: some View {
        ZStack {
            // Background - warm charcoal
            Color(red: 0.11, green: 0.105, blue: 0.102) // #1C1B1A
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
        .environmentObject(notesViewModel)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
