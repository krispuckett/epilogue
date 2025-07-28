import SwiftUI

struct UnifiedChatInputBar: View {
    @Binding var messageText: String
    @Binding var showingCommandPalette: Bool  // Triggers existing command palette
    @FocusState.Binding var isInputFocused: Bool
    
    // Context for dynamic placeholders
    let currentBook: Book?
    let onSend: () -> Void
    
    // Microphone state
    @Binding var isRecording: Bool
    let onMicrophoneTap: () -> Void
    
    private var placeholderText: String {
        if let book = currentBook {
            return "Ask about \(book.title)..."
        } else {
            return "Ask about your books..."
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
                // Library navigation button
                Button {
                    // Navigate to library tab
                    NotificationCenter.default.post(name: Notification.Name("NavigateToTab"), object: 0)
                    HapticManager.shared.lightTap()
                } label: {
                    // Try custom image first, fallback to system icon
                    if let _ = UIImage(named: "glass-book-open") {
                        Image("glass-book-open")
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: 44, height: 44)
                .glassEffect(.regular, in: .circle)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
                
                // Main input bar - matching command palette style
                HStack(spacing: 10) {
                // Command icon - matching search icon style
                Image(systemName: "command")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .onTapGesture {
                        showingCommandPalette = true
                    }
                
                // Text input - matching command palette
                TextField(placeholderText, text: $messageText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if !messageText.isEmpty {
                            onSend()
                        }
                    }
                
                // Action buttons
                HStack(spacing: 8) {
                    // Microphone button
                    Button {
                        onMicrophoneTap()
                    } label: {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 16))
                            .foregroundStyle(isRecording ? .red : .white.opacity(0.5))
                            .animation(.easeInOut(duration: 0.2), value: isRecording)
                    }
                    .buttonStyle(.plain)
                    
                    // Send button (visible when text is entered)
                    if !messageText.isEmpty {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: messageText.isEmpty)
    }
}

// MARK: - Integration Extension

extension UnifiedChatInputBar {
    /// Convenience initializer for simple use cases
    init(
        messageText: Binding<String>,
        showingCommandPalette: Binding<Bool>,
        isInputFocused: FocusState<Bool>.Binding,
        isRecording: Binding<Bool>,
        onSend: @escaping () -> Void,
        onMicrophoneTap: @escaping () -> Void
    ) {
        self._messageText = messageText
        self._showingCommandPalette = showingCommandPalette
        self._isInputFocused = isInputFocused
        self._isRecording = isRecording
        self.currentBook = nil
        self.onSend = onSend
        self.onMicrophoneTap = onMicrophoneTap
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            UnifiedChatInputBar(
                messageText: .constant(""),
                showingCommandPalette: .constant(false),
                isInputFocused: FocusState<Bool>().projectedValue,
                currentBook: nil,
                onSend: {},
                isRecording: .constant(false),
                onMicrophoneTap: {}
            )
            .padding()
        }
    }
}