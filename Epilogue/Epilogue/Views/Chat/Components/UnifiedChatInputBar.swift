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
                
                // Main input bar - liquid glass style matching command palette
                HStack(spacing: 0) {
                    // Command icon - matching search icon style
                    Image(systemName: "command")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                        .onTapGesture {
                            showingCommandPalette = true
                        }
                    
                    // Text input - matching command palette
                    ZStack(alignment: .leading) {
                        if messageText.isEmpty {
                            Text(placeholderText)
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))
                        }
                        
                        TextField("", text: $messageText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .focused($isInputFocused)
                            .lineLimit(1)
                            .submitLabel(.send)
                            .onSubmit {
                                if !messageText.isEmpty {
                                    onSend()
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        // Waveform toggle button (always shows waveform)
                        Button {
                            print("🎤 UnifiedChatInputBar: Microphone button tapped")
                            onMicrophoneTap()
                        } label: {
                            Image(systemName: "waveform")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(
                                    isRecording ? 
                                    Color(red: 1.0, green: 0.55, blue: 0.26) : 
                                    Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.7)
                                )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .frame(minWidth: 44, minHeight: 44)
                        
                        // Send button (visible when text is entered) 
                        if !messageText.isEmpty {
                            Button(action: onSend) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white, Color(red: 1.0, green: 0.55, blue: 0.26))
                            }
                            .buttonStyle(.plain)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                        }
                    }
                    .padding(.trailing, 12)
                }
                .frame(minHeight: 36)
                .glassEffect(in: RoundedRectangle(cornerRadius: 18))
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
                        .allowsHitTesting(false) // Don't intercept button taps
                }
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