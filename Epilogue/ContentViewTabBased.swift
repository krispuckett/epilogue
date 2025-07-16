import SwiftUI

struct ContentViewTabBased: View {
    @State private var selectedTab = 0
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    @State private var showCommand = false
    @State private var commandOrbOffset: CGSize = .zero
    @Namespace private var glassAnimation
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            // Native TabView with automatic blur
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
            
            // Command interface overlay
            ZStack {
                if showCommand {
                    // Full-screen dimming
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showCommand = false
                            }
                        }
                    
                    // Command palette
                    CommandPalette(
                        isPresented: $showCommand,
                        namespace: glassAnimation
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.1).combined(with: .opacity),
                        removal: .scale(scale: 0.1).combined(with: .opacity)
                    ))
                }
                
                // Floating plus button
                if !showCommand {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            Button {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    showCommand = true
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay {
                                            Circle()
                                                .strokeBorder(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(red: 1.0, green: 0.55, blue: 0.26),
                                                            Color(red: 1.0, green: 0.7, blue: 0.4)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 0.5
                                                )
                                        }
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                                        .rotationEffect(.degrees(showCommand ? 45 : 0))
                                }
                                .frame(width: 56, height: 56)
                                .glassEffect()
                                .shadow(
                                    color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3),
                                    radius: 12,
                                    y: 4
                                )
                            }
                            .matchedGeometryEffect(id: "commandOrb", in: glassAnimation)
                            .padding(.trailing, 20)
                            .padding(.bottom, 90)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .identity
                    ))
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showCommand)
        }
        .environmentObject(libraryViewModel)
        .environmentObject(notesViewModel)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentViewTabBased()
}