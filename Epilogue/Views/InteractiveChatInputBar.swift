import SwiftUI

struct InteractiveChatInputBar: View {
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showingBookPicker = false
    @State private var showQuickSuggestions = false
    let onSendMessage: (String, Book?) -> Void
    let onSelectBook: () -> Void
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Quick suggestions when plus button is tapped
            if showQuickSuggestions {
                SmartChatSuggestions(onSelectSuggestion: { suggestion in
                    messageText = suggestion
                    showQuickSuggestions = false
                    // Optionally auto-send or just populate the field
                    // sendMessage()
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 4)
            }
            
            // Main input bar - iMessage style
            HStack(spacing: 8) {
                // Plus button (left side)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showQuickSuggestions.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.tint(Color.white.opacity(0.1)), in: Circle())
                }
                
                // Input field container with glass effect
                HStack(spacing: 0) {
                    // Question mark icon
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        .font(.system(size: 20, weight: .medium))
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                    
                    // Text field
                    ZStack(alignment: .leading) {
                        if messageText.isEmpty {
                            Text("Ask your books anything...")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))
                        }
                        
                        TextField("", text: $messageText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .focused($isInputFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .onSubmit {
                                sendMessage()
                            }
                            .onChange(of: messageText) { _, newValue in
                                // Hide suggestions when user starts typing
                                if !newValue.isEmpty && showQuickSuggestions {
                                    showQuickSuggestions = false
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    
                    // Book icon button
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
                
                // Send button (appears when there's text)
                if !messageText.isEmpty {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white, Color(red: 1.0, green: 0.55, blue: 0.26))
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showQuickSuggestions)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: !messageText.isEmpty)
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Check if message mentions a book with @ symbol
        if messageText.contains("@") {
            // Parse for book mentions
            // For now, just send as general message
            onSendMessage(messageText, nil)
        } else {
            // General message
            onSendMessage(messageText, nil)
        }
        
        messageText = ""
        isInputFocused = false
    }
}

// Smart suggestions component
struct SmartChatSuggestions: View {
    let onSelectSuggestion: (String) -> Void
    
    let suggestions = [
        ("Themes", "sparkles", "What are the main themes in my recent reads?"),
        ("Similar", "books.vertical", "Recommend a book similar to what I've been reading"),
        ("Summary", "text.alignleft", "Summarize the plot of my last finished book"),
        ("Insights", "lightbulb", "Share insights about my reading habits")
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestions, id: \.2) { (title, icon, suggestion) in
                    Button {
                        onSelectSuggestion(suggestion)
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
        .padding(.bottom, 8)
    }
}