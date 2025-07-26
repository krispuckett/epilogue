import SwiftUI

struct ChatInputBar: View {
    let onStartGeneralChat: () -> Void
    let onSelectBook: () -> Void
    let onStartAmbient: () -> Void
    @FocusState private var isFocused: Bool
    @State private var showCommandPalette = false
    @State private var isAmbientActive = false
    @Namespace private var commandPaletteNamespace
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Ambient orb button (left side)
                AmbientOrbButton(isActive: $isAmbientActive, onTap: onStartAmbient)
                
                // Command palette button
                Button {
                    showCommandPalette = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.tint(Color.white.opacity(0.1)), in: Circle())
                }
                
                // Tappable input area container with glass effect
                Button {
                    onStartGeneralChat()
                } label: {
                    HStack(spacing: 0) {
                        // Question mark icon
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                            .font(.system(size: 20, weight: .medium))
                            .padding(.leading, 12)
                            .padding(.trailing, 8)
                        
                        // Placeholder text
                        Text("Ask your books anything...")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Persistent book icon inside the input field
                        Button(action: onSelectBook) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        }
                        .padding(.trailing, 12)
                    }
                    .frame(minHeight: 36)
                    .glassEffect(.regular.tint(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.15)), in: RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3),
                                        Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCommandPalette)
        .sheet(isPresented: $showCommandPalette) {
            LiquidCommandPalette(
                isPresented: $showCommandPalette,
                animationNamespace: commandPaletteNamespace
            )
            .environmentObject(notesViewModel)
            .environmentObject(libraryViewModel)
        }
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.tint(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3)), in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.5),
                                            Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2), radius: 8, y: 4)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 40)
    }
}