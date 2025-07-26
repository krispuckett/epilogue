import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    @State private var showCommandPalette = false
    @State private var selectedDetent: PresentationDetent = .height(300)
    @State private var showVoiceTest = false
    @State private var showWhisperModels = false
    @Namespace private var animation
    
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
                
                ChatView()
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
        // Voice Test Button (temporary for testing) - HIDDEN
        /*
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 12) {
                // Whisper Model Manager Button
                Button {
                    showWhisperModels = true
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .padding(12)
                        .glassEffect(in: Circle())
                }
                
                // Voice Test Button
                Button {
                    showVoiceTest = true
                } label: {
                    Image(systemName: "mic.badge.xmark")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .padding(12)
                        .glassEffect(in: Circle())
                }
            }
            .padding(.top, 60)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showVoiceTest) {
            VoiceTestLauncherView()
        }
        .sheet(isPresented: $showWhisperModels) {
            NavigationStack {
                TranscriptionDebugView()
                    .navigationTitle("Transcription Debug")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showWhisperModels = false
                            }
                        }
                    }
            }
        }
        */
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
        .onAppear {
            // Clean expired cache entries on app launch
            ResponseCache.shared.cleanExpiredEntries()
            
            // Prepare haptic generators
            HapticManager.shared.prepareAll()
        }
    }
}

#Preview {
    ContentView()
}

