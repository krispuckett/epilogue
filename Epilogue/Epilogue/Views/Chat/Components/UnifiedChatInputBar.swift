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
    
    // Color palette for adaptive UI
    let colorPalette: ColorPalette?
    
    private var placeholderText: String {
        if let book = currentBook {
            return "Ask about \(book.title)..."
        } else {
            return "Ask about your books..."
        }
    }
    
    private var adaptiveUIColor: Color {
        if let palette = colorPalette {
            return palette.adaptiveUIColor
        } else {
            return DesignSystem.Colors.primaryAccent
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
                // Main input bar - liquid glass style matching command palette
                HStack(spacing: 0) {
                    // Command icon - matching search icon style
                    Image(systemName: "command")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(adaptiveUIColor)
                        .frame(height: 36)
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingCommandPalette = true
                        }
                    
                    // Text input - matching command palette
                    ZStack(alignment: .leading) {
                        if messageText.isEmpty {
                            Text(placeholderText)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .font(.system(size: 16))
                                .lineLimit(1)
                        }
                        
                        TextField("", text: $messageText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .focused($isInputFocused)
                            .lineLimit(1...5)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
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
                                    adaptiveUIColor : 
                                    adaptiveUIColor.opacity(0.7)
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
                                    .foregroundStyle(.white, adaptiveUIColor)
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
                .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    adaptiveUIColor.opacity(0.3),
                                    adaptiveUIColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                        .allowsHitTesting(false) // Don't intercept button taps
                }
        }
        .animation(DesignSystem.Animation.springStandard, value: messageText.isEmpty)
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
        onMicrophoneTap: @escaping () -> Void,
        colorPalette: ColorPalette? = nil
    ) {
        self._messageText = messageText
        self._showingCommandPalette = showingCommandPalette
        self._isInputFocused = isInputFocused
        self._isRecording = isRecording
        self.currentBook = nil
        self.onSend = onSend
        self.onMicrophoneTap = onMicrophoneTap
        self.colorPalette = colorPalette
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
                onMicrophoneTap: {},
                colorPalette: nil
            )
            .padding()
        }
    }
}