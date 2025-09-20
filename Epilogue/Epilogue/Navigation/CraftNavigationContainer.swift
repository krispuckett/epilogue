import SwiftUI

// MARK: - Main Navigation Container
struct CraftNavigationContainer: View {
    @State private var selectedTab: TabItem = .library
    @State private var showCreateMenu = false
    @State private var showAmbientMode = false
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared

    enum TabItem: String, CaseIterable {
        case library = "Library"
        case notes = "Notes"
        case chat = "Chat"

        var iconName: String {
            switch self {
            case .library: return "books.vertical"
            case .notes: return "note.text"
            case .chat: return "bubble.left.and.bubble.right"
            }
        }

        // Your custom icons
        var customIcon: String {
            switch self {
            case .library: return "glass-book-open"
            case .notes: return "glass-feather"
            case .chat: return "glass-msgs"
            }
        }
    }

    var body: some View {
        ZStack {
            // Main content
            Group {
                switch selectedTab {
                case .library:
                    NavigationStack {
                        LibraryView()
                    }
                case .notes:
                    NavigationStack {
                        CleanNotesView()
                    }
                case .chat:
                    ChatViewWrapper()
                }
            }

            // Bottom navigation area
            VStack {
                Spacer()

                // Navigation components
                ZStack(alignment: .bottom) {
                    // Extended glass background for safe area
                    GlassTabBarBackground()

                    // Main navigation bar
                    HStack(alignment: .bottom, spacing: 16) {
                        // Tab bar with ambient orb
                        CraftStyleTabBar(
                            selectedTab: $selectedTab,
                            showAmbientMode: $showAmbientMode
                        )

                        // Floating create button (outside tab bar)
                        FloatingCreateButton(showMenu: $showCreateMenu)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .sheet(isPresented: $showCreateMenu) {
            CreateMenuSheet()
        }
        .fullScreenCover(isPresented: $showAmbientMode) {
            // Use the existing AmbientModeView
            AmbientModeView()
        }
        .environmentObject(libraryViewModel)
        .environmentObject(notesViewModel)
        .environmentObject(navigationCoordinator)
    }
}

// MARK: - Glass Tab Bar Background
struct GlassTabBarBackground: View {
    var body: some View {
        // This creates the iOS 26 blur that extends through safe area
        Rectangle()
            .fill(Color.clear)
            .frame(height: 100) // Extends beyond tab bar height
            .glassEffect()
            .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Craft-Style Tab Bar
struct CraftStyleTabBar: View {
    @Binding var selectedTab: CraftNavigationContainer.TabItem
    @Binding var showAmbientMode: Bool
    @Namespace private var tabAnimation
    @EnvironmentObject var libraryViewModel: LibraryViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Three main tabs
            ForEach(CraftNavigationContainer.TabItem.allCases, id: \.self) { tab in
                TabItemView(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: tabAnimation
                ) {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85)) {
                        selectedTab = tab
                    }
                }
            }

            // Divider
            Divider()
                .frame(height: 28)
                .padding(.horizontal, 12)

            // Ambient Mode Orb (special section)
            AmbientModeSection(isActive: $showAmbientMode)
                .environmentObject(libraryViewModel)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(height: 64)
        .glassEffect(in: RoundedRectangle(cornerRadius: 32))
    }
}

// MARK: - Individual Tab Item
struct TabItemView: View {
    let tab: CraftNavigationContainer.TabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon with selection indicator
                ZStack {
                    if isSelected {
                        // Selection background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                            .frame(width: 40, height: 32)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }

                    Image(tab.customIcon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundStyle(isSelected ? DesignSystem.Colors.primaryAccent : Color.secondary)
                }

                // Label
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Ambient Mode Section (with Metal Shader Orb)
struct AmbientModeSection: View {
    @Binding var isActive: Bool
    @State private var orbPulse = false
    @EnvironmentObject var libraryViewModel: LibraryViewModel

    var body: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.4)) {
                isActive.toggle()
                orbPulse = true
            }

            // Haptic feedback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // Open ambient mode
            if let currentBook = libraryViewModel.currentDetailBook {
                SimplifiedAmbientCoordinator.shared.openAmbientReading(with: currentBook)
            } else {
                SimplifiedAmbientCoordinator.shared.openAmbientReading()
            }
        } label: {
            VStack(spacing: 6) {
                // Ambient Orb Container
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    DesignSystem.Colors.primaryAccent.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                        .blur(radius: 8)
                        .scaleEffect(orbPulse ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.6), value: orbPulse)

                    // Your Metal Shader Orb - using the existing AmbientOrbButton
                    AmbientOrbButton(size: 24) {
                        // Action handled by parent button
                    }
                    .allowsHitTesting(false)
                }
                .frame(width: 32, height: 32)

                // Label
                Text("Ambient")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.secondary)
            }
            .frame(width: 60)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Floating Create Button (Craft-style)
struct FloatingCreateButton: View {
    @Binding var showMenu: Bool
    @State private var isPressed = false

    var body: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.3)) {
                showMenu = true
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .glassEffect(in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.interactiveSpring(response: 0.3)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Create Menu Sheet
struct CreateMenuSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                // Menu options
                VStack(spacing: 12) {
                    CreateMenuItem(
                        icon: "book.closed",
                        title: "Add Book",
                        subtitle: "Search and add to library"
                    ) {
                        // Action
                        NotificationCenter.default.post(name: Notification.Name("ShowBookSearch"), object: nil)
                        dismiss()
                    }

                    CreateMenuItem(
                        icon: "note.text",
                        title: "Create Note",
                        subtitle: "Capture a thought or idea"
                    ) {
                        // Action
                        NotificationCenter.default.post(name: Notification.Name("CreateNewNote"), object: nil)
                        dismiss()
                    }

                    CreateMenuItem(
                        icon: "quote.bubble",
                        title: "Save Quote",
                        subtitle: "Remember a passage"
                    ) {
                        // Action
                        NotificationCenter.default.post(name: Notification.Name("ShowQuoteCapture"), object: nil)
                        dismiss()
                    }

                    CreateMenuItem(
                        icon: "magnifyingglass",
                        title: "Search Books",
                        subtitle: "Find new titles to read"
                    ) {
                        // Action
                        NotificationCenter.default.post(name: Notification.Name("ShowBookSearch"), object: nil)
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
            .presentationBackground {
                // iOS 26 glass background for sheet
                Color.clear.glassEffect()
            }
        }
    }
}

// MARK: - Create Menu Item
struct CreateMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon container
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .frame(width: 44, height: 44)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 12))

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }
}