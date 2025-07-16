import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    @State private var showCommandPalette = false
    @State private var selectedDetent: PresentationDetent = .height(300)
    @Namespace private var animation
    
    init() {
        print("🏠 DEBUG: ContentView init")
        
        // Customize tab bar appearance for iOS 26
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            // Native TabView with automatic blur - DO NOT MODIFY
            TabView(selection: $selectedTab) {
                NavigationStack {
                    LibraryView()
                }
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(0)
                
                NavigationStack {
                    NotesView()
                }
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(1)
                
                NavigationStack {
                    ChatView()
                }
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .tag(2)
            }
            .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
            .environmentObject(libraryViewModel)
            .environmentObject(notesViewModel)
            .safeAreaInset(edge: .bottom) {
                // Quick Add button positioned right above tab bar
                if selectedTab != 2 && !showCommandPalette && !notesViewModel.isEditingNote {
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            HapticManager.shared.lightTap()
                            showCommandPalette = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                            Text("Quick Add")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .glassEffect(in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .matchedGeometryEffect(id: "commandInput", in: animation)
                    .padding(.bottom, 56) // 4-6px above tab bar
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
        }
        
        // Command palette overlay
        .overlay {
            if showCommandPalette {
                LiquidCommandPalette(
                    isPresented: $showCommandPalette,
                    animationNamespace: animation
                )
                .environmentObject(libraryViewModel)
                .environmentObject(notesViewModel)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .bottom)
                        .combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .bottom)
                        .combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showCommandPalette)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
