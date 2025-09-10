import SwiftUI

struct ChatInputBar: View {
    let onStartGeneralChat: () -> Void
    let onSelectBook: () -> Void
    let onStartAmbient: () -> Void
    @FocusState private var isFocused: Bool
    @State private var showCommandPalette = false
    @State private var commandPaletteText = ""
    @State private var showNavigationMenu = false
    @State private var selectedBook: Book?
    @State private var isAmbientActive = false
    @State private var isProcessing = false
    @Namespace private var commandPaletteNamespace
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // Raycast-style input bar
        HStack(spacing: 12) {
            // Book selector button (left side) - 20x30pt thumbnail
            Button {
                onSelectBook()
            } label: {
                if let book = selectedBook, let coverURL = book.coverImageURL {
                    SharedBookCoverView(coverURL: coverURL, width: 20, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.3))
                        .frame(width: 20, height: 30)
                        .overlay {
                            Image(systemName: "book.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                }
            }
            
            // Main input field (center) - expandable with AI shimmer
            AIEnhancedInputField(
                placeholder: "Ask your books anything",
                isProcessing: isProcessing,
                shimmerColors: [
                    DesignSystem.Colors.primaryAccent,
                    Color(red: 1.0, green: 0.7, blue: 0.4),
                    Color(red: 1.0, green: 0.8, blue: 0.6)
                ]
            ) {
                // Simulate processing for demo
                isProcessing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isProcessing = false
                    onStartGeneralChat()
                }
            }
            
            // Navigation button (glass-book-open icon)
            Button {
                showNavigationMenu = true
            } label: {
                Image("glass-book-open")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            // Waveform button (right side) with hero transition
            WaveformHeroButton {
                onStartAmbient()
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .padding(.vertical, 16)
        .frame(height: 60)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .overlay {
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.bottom, 20)
        .confirmationDialog("Navigate to", isPresented: $showNavigationMenu) {
            Button {
                navigateToLibrary()
            } label: {
                Label("Library", image: "glass-book-open")
            }
            
            Button {
                navigateToNotes()
            } label: {
                Label("Notes", image: "glass-feather")
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showCommandPalette) {
            IntelligentCommandPalette(
                isPresented: $showCommandPalette,
                commandText: $commandPaletteText
            )
            .environmentObject(notesViewModel)
            .environmentObject(libraryViewModel)
        }
    }
    
    private func navigateToLibrary() {
        // Navigate to library tab
        NotificationCenter.default.post(name: Notification.Name("NavigateToTab"), object: 0)
    }
    
    private func navigateToNotes() {
        // Navigate to notes tab
        NotificationCenter.default.post(name: Notification.Name("NavigateToTab"), object: 1)
    }
}

// Chat suggestion pills component
struct ChatSuggestionPills: View {
    let suggestions = [
        ("Reading", "books.vertical", "What have I been reading lately?"),
        ("Recommend", "sparkles", "Recommend my next book"),
        ("Insights", "lightbulb", "Share insights about my library"),
        ("Themes", "text.alignleft", "Common themes in my books")
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestions, id: \.2) { (title, icon, _) in
                    Button {
                        // Action handled by parent when implemented
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .medium))
                            Text(title)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.3)), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            DesignSystem.Colors.primaryAccent.opacity(0.5),
                                            DesignSystem.Colors.primaryAccent.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(color: DesignSystem.Colors.primaryAccent.opacity(0.2), radius: 8, y: 4)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        }
        .frame(height: 40)
    }
}
