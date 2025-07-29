import SwiftUI

struct ContentView: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @State private var selectedTab = 0
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    @State private var showCommandPalette = false
    @State private var selectedDetent: PresentationDetent = .height(300)
    @Namespace private var animation
    @State private var showPrivacySettings = false
    
    init() {
        print("🏠 DEBUG: ContentView init")
        
        // Customize tab bar appearance for iOS 26
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            // Native TabView with automatic blur - DO NOT MODIFY
            TabView(selection: Binding(
                get: { 
                    switch navigationCoordinator.selectedTab {
                    case .library: return 0
                    case .notes: return 1
                    case .chat: return 2
                    }
                },
                set: { newValue in
                    selectedTab = newValue
                    switch newValue {
                    case 0: navigationCoordinator.selectedTab = .library
                    case 1: navigationCoordinator.selectedTab = .notes
                    case 2: navigationCoordinator.selectedTab = .chat
                    default: break
                    }
                }
            )) {
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
                    NotesView()
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
                            .interpolation(.high)
                    }
                }
                .tag(2)
            }
            .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
            .environmentObject(libraryViewModel)
            .environmentObject(notesViewModel)
            .environmentObject(navigationCoordinator)
            .toolbar {
                // Privacy settings button (only on Library tab)
                if selectedTab == 0 {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showPrivacySettings = true
                        } label: {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        }
                    }
                }
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                // Haptic feedback on tab change
                HapticManager.shared.selectionChanged()
            }
            .safeAreaInset(edge: .bottom) {
                // Quick Add button positioned right above tab bar
                if selectedTab != 2 && !showCommandPalette && !notesViewModel.isEditingNote {
                    Button(action: {
                        HapticManager.shared.lightTap()
                        showCommandPalette = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                            Text("Quick Actions")
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCommandPalette)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPrivacySettings) {
            NavigationView {
                PrivacySettingsView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showPrivacySettings = false
                            }
                        }
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToBook"))) { notification in
            if notification.object is Book {
                selectedTab = 0  // Switch to library tab
                // TODO: Implement scrolling to specific book in LibraryView
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToNote"))) { notification in
            if notification.object is Note {
                selectedTab = 1  // Switch to notes tab
                // NotesView will handle the scrolling and editing
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToTab"))) { notification in
            if let tabIndex = notification.object as? Int {
                selectedTab = tabIndex
            }
        }
        .onAppear {
            // Defer cache cleaning to background after launch
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                ResponseCache.shared.cleanExpiredEntries()
            }
            
            // Prepare only essential haptic generators
            HapticManager.shared.lightTap() // Prepare the most used one
        }
    }
}

#Preview {
    ContentView()
}

