import SwiftUI

struct MainNavigationView: View {
    @State private var selectedTab: Tab = .library
    @State private var selectedFilter: BookFilter = .all
    @Namespace private var namespace
    
    enum Tab: String, CaseIterable {
        case library = "Library"
        case notes = "Notes"
        case chat = "Chat"
        
        var icon: String {
            switch self {
            case .library: return "books.vertical"
            case .notes: return "note.text"
            case .chat: return "message"
            }
        }
    }
    
    enum BookFilter: String, CaseIterable {
        case all = "All"
        case reading = "Reading"
        case finished = "Finished"
    }
    
    var body: some View {
        ZStack {
            // Rich gradient background to show glass blur
            AnimatedBackground()
            
            // Main content
            VStack(spacing: 0) {
                // Top navigation pills with glass
                TopNavigationPills(selectedFilter: $selectedFilter, namespace: namespace)
                    .padding(.top, 60)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                // Content area (placeholder for now)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(0..<12) { index in
                            BookCard(index: index)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for tab bar
                }
            }
            
            // Bottom navigation with glass
            VStack {
                Spacer()
                BottomTabBar(selectedTab: $selectedTab)
            }
            
            // Floating add button with thick glass
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingAddButton {
                        // Action placeholder
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 110) // Above tab bar
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Top Navigation Pills
struct TopNavigationPills: View {
    @Binding var selectedFilter: MainNavigationView.BookFilter
    let namespace: Namespace.ID
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(MainNavigationView.BookFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.labelLarge)
                        .foregroundStyle(selectedFilter == filter ? .white : .white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background {
                            if selectedFilter == filter {
                                Capsule()
                                    .fill(.white.opacity(0.15))
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                }
                .glassEffect(in: Capsule()) // ✅ CORRECT: Direct glass, no background!
            }
        }
    }
}

// MARK: - Bottom Tab Bar
struct BottomTabBar: View {
    @Binding var selectedTab: MainNavigationView.Tab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainNavigationView.Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 24))
                            .symbolVariant(selectedTab == tab ? .fill : .none)
                        
                        Text(tab.rawValue)
                            .font(.labelSmall)
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34) // Safe area
        .glassEffect() // ✅ CORRECT: Direct glass application!
    }
}

// MARK: - Floating Add Button
struct FloatingAddButton: View {
    @State private var isPressed = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .glassEffect(in: Circle()) // ✅ CORRECT: Glass with shape!
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Book Card (Placeholder)
struct BookCard: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Book cover placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hue: Double(index) / 12, saturation: 0.7, brightness: 0.8))
                .aspectRatio(0.65, contentMode: .fit)
                .overlay {
                    Image(systemName: "book.closed")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                }
            
            Text("Book Title \(index + 1)")
                .font(.titleSmall)
                .foregroundStyle(.white)
                .lineLimit(2)
            
            Text("Author Name")
                .font(.bodySmall)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16)) // ✅ Glass on cards too!
    }
}

// MARK: - Animated Background
struct AnimatedBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.3),
                    Color(red: 0.2, green: 0.1, blue: 0.4),
                    Color(red: 0.3, green: 0.2, blue: 0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated blobs for glass to blur
            ForEach(0..<3) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hue: Double(index) / 3, saturation: 1, brightness: 0.8).opacity(0.6),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(
                        x: animate ? CGFloat.random(in: -100...100) : CGFloat.random(in: -100...100),
                        y: animate ? CGFloat.random(in: -200...200) : CGFloat.random(in: -200...200)
                    )
                    .blur(radius: 20)
                    .animation(
                        .easeInOut(duration: Double.random(in: 8...12))
                        .repeatForever(autoreverses: true),
                        value: animate
                    )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    MainNavigationView()
}