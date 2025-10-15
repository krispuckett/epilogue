import SwiftUI

// MARK: - Input Context
enum InputContext {
    case library
    case chat(book: Book?)
    case notes
    case bookDetail(book: Book)
    case quickActions
    case bookNote(book: Book)  // New context for adding notes from BookView
    
    var placeholderText: String {
        switch self {
        case .library:
            return "Search, add books, or capture..."
        case .chat(let book):
            if let book = book {
                return "Ask about \(book.title)..."
            } else {
                return "Ask about your books..."
            }
        case .notes:
            return "Search notes or create new..."
        case .bookDetail(let book):
            return "Add quote or note from \(book.title)..."
        case .quickActions:
            return "Search, Add Note, Add Book..."
        case .bookNote(let book):
            return "Add your quick note or quote..."
        }
    }
}

// MARK: - Universal Input Bar (Extracted from UnifiedChatInputBar)
struct UniversalInputBar: View {
    @Binding var messageText: String
    @Binding var showingCommandPalette: Bool
    @FocusState.Binding var isInputFocused: Bool
    
    // Context and actions
    let context: InputContext
    let onSend: () -> Void
    let onMicrophoneTap: () -> Void
    var onCommandTap: (() -> Void)? = nil
    
    // State
    @Binding var isRecording: Bool
    let colorPalette: ColorPalette?
    var isAmbientMode: Bool = false
    
    // Computed properties (exact same as UnifiedChatInputBar)
    private var placeholderText: String {
        return context.placeholderText
    }
    
    private var adaptiveUIColor: Color {
        if let palette = colorPalette {
            return palette.adaptiveUIColor
        } else {
            return DesignSystem.Colors.primaryAccent
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Main input bar - EXACT copy from UnifiedChatInputBar
            HStack(spacing: 0) {
                // Command icon - amber accent (hide for bookNote context)
                if case .bookNote = context {
                    // No command icon for book note context
                } else {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                        .frame(height: 36)
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let onCommandTap = onCommandTap {
                                onCommandTap()
                            } else {
                                showingCommandPalette = true
                            }
                        }
                }
                
                // Text input with amber theme
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
                        .accentColor(DesignSystem.Colors.primaryAccent)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .fixedSize(horizontal: false, vertical: true)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .onSubmit {
                            if !messageText.isEmpty {
                                onSend()
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.leading, {
                    if case .bookNote = context {
                        return 12
                    }
                    return 0
                }()) // Extra padding when no command icon

                // Removed - send button is now integrated with waveform button
                Spacer()
                    .frame(width: 12)
            }
            .frame(minHeight: 44)
            .glassEffect(in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
            
            // Morphing button - context aware
            if case .bookNote = context {
                // For bookNote context: always show arrow.up, no waveform
                Button {
                    onSend() // Always send, even if empty (will be handled upstream)
                } label: {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .glassEffect()

                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    }
                }
                .buttonStyle(.plain)
                .opacity(messageText.isEmpty ? 0.6 : 1.0) // Dimmed when empty
            } else if case .quickActions = context {
                // For quick actions (library command palette): always show arrow.up
                Button {
                    onSend()
                } label: {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .glassEffect()

                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    }
                }
                .buttonStyle(.plain)
                .opacity(messageText.isEmpty ? 0.6 : 1.0) // Dimmed when empty
            } else {
                // Default behavior: waveform when empty, submit when has text
                Button {
                    if !messageText.isEmpty {
                        // Submit the message
                        onSend()
                    } else {
                        // Trigger microphone/voice input
                        onMicrophoneTap()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .glassEffect()

                        Image(systemName: messageText.isEmpty ? "waveform" : "arrow.up")
                            .font(.system(size: 18, weight: messageText.isEmpty ? .medium : .semibold))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent)
                            .contentTransition(.symbolEffect(.replace))
                            .scaleEffect(isRecording && messageText.isEmpty ? 1.1 : 1.0)
                            .animation(DesignSystem.Animation.easeQuick, value: isRecording)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .animation(DesignSystem.Animation.springStandard, value: messageText.isEmpty)
    }
}

// MARK: - Modal Overlay Version for Quick Actions
struct UniversalInputBarOverlay: View {
    @Binding var isPresented: Bool
    @Binding var messageText: String
    @FocusState.Binding var isInputFocused: Bool
    
    let context: InputContext
    let onSubmit: (String) -> Void
    let onMicrophoneTap: () -> Void
    let colorPalette: ColorPalette?
    
    var showingCommandPalette: Bool = false
    var onCommandPaletteTap: (() -> Void)? = nil
    
    @State private var isRecording = false
    
    var body: some View {
        ZStack {
            // Backdrop dimming
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissInputBar()
                }
            
            VStack {
                Spacer()
                
                // Universal Input Bar
                UniversalInputBar(
                    messageText: $messageText,
                    showingCommandPalette: .constant(false),
                    isInputFocused: $isInputFocused,
                    context: context,
                    onSend: {
                        let text = messageText
                        messageText = ""
                        onSubmit(text)
                        dismissInputBar()
                    },
                    onMicrophoneTap: onMicrophoneTap,
                    onCommandTap: onCommandPaletteTap,
                    isRecording: $isRecording,
                    colorPalette: colorPalette
                )
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.vertical, 16)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
        .onAppear {
            isInputFocused = true
        }
        .onDisappear {
            isInputFocused = false
        }
    }
    
    private func dismissInputBar() {
        isInputFocused = false
        withAnimation(DesignSystem.Animation.easeStandard) {
            isPresented = false
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var text = ""
    @Previewable @State var isPresented = true
    @FocusState var isFocused: Bool
    
    return ZStack {
        Color.black.ignoresSafeArea()
        
        if isPresented {
            UniversalInputBarOverlay(
                isPresented: $isPresented,
                messageText: $text,
                isInputFocused: $isFocused,
                context: .quickActions,
                onSubmit: { text in
                    #if DEBUG
                    print("Submitted: \(text)")
                    #endif
                },
                onMicrophoneTap: {
                    #if DEBUG
                    print("Microphone tapped")
                    #endif
                },
                colorPalette: nil,
                showingCommandPalette: false,
                onCommandPaletteTap: {
                    #if DEBUG
                    print("Command palette tapped")
                    #endif
                }
            )
        }
    }
}