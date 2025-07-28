import SwiftUI

struct UnifiedChatInputBar: View {
    @Binding var messageText: String
    @Binding var showingCommandPalette: Bool  // Triggers existing command palette
    @FocusState.Binding var isInputFocused: Bool
    
    // Context for dynamic placeholders
    let currentBook: Book?
    let onSend: () -> Void
    
    // Command detection
    @State private var activeCommand: CommandType? = nil
    @State private var showCommandHint = false
    
    // Microphone state (WhisperManager will be implemented later)
    @State private var isRecording = false
    
    enum CommandType {
        case slash      // Book switcher
        case at         // Quotes/notes
        case question   // Quick actions
        
        var hint: String {
            switch self {
            case .slash: return "Switch book context"
            case .at: return "Browse quotes & notes"
            case .question: return "Quick actions"
            }
        }
        
        var icon: String {
            switch self {
            case .slash: return "books.vertical"
            case .at: return "quote.opening"
            case .question: return "questionmark.circle"
            }
        }
    }
    
    private var placeholderText: String {
        if let book = currentBook {
            return "Ask about \(book.title)..."
        } else {
            return "Ask about your books..."
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Command hint overlay
            if showCommandHint, let command = activeCommand {
                commandHintView(for: command)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Main input bar
            HStack(spacing: 12) {
                // Command icon
                Image(systemName: "command.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.6))
                    .onTapGesture {
                        showingCommandPalette = true
                    }
                
                // Text input
                TextField(placeholderText, text: $messageText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if !messageText.isEmpty {
                            onSend()
                        }
                    }
                    .onChange(of: messageText) { _, newValue in
                        handleCommandDetection(newValue)
                    }
                
                // Action buttons
                HStack(spacing: 8) {
                    // Microphone button
                    Button {
                        // TODO: Integrate with WhisperManager when implemented
                        isRecording.toggle()
                        HapticManager.shared.lightTap()
                    } label: {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 18))
                            .foregroundStyle(isRecording ? .red : .white.opacity(0.6))
                            .animation(.easeInOut(duration: 0.2), value: isRecording)
                    }
                    .buttonStyle(.plain)
                    
                    // Send button (visible when text is entered)
                    if !messageText.isEmpty {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCommandHint)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: messageText.isEmpty)
    }
    
    // MARK: - Command Hint View
    
    private func commandHintView(for command: CommandType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: command.icon)
                .font(.system(size: 14))
            
            Text(command.hint)
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
            
            Text("Press Enter")
                .font(.system(size: 12))
                .opacity(0.6)
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
    
    // MARK: - Command Detection
    
    private func handleCommandDetection(_ text: String) {
        // Check for commands at the start of the text
        if text.hasPrefix("/") {
            activeCommand = .slash
            showCommandHint = true
            
            // Trigger existing command palette
            if text == "/" {
                showingCommandPalette = true
                // Clear the slash from input
                messageText = ""
                showCommandHint = false
                activeCommand = nil
            }
        } else if text.hasPrefix("@") {
            activeCommand = .at
            showCommandHint = true
            
            // TODO: Show quotes/notes picker
            if text == "@" {
                // Will be implemented with quotes/notes view
            }
        } else if text.hasPrefix("?") {
            activeCommand = .question
            showCommandHint = true
            
            // TODO: Show quick actions
            if text == "?" {
                // Will be implemented with quick actions menu
            }
        } else {
            showCommandHint = false
            activeCommand = nil
        }
    }
}

// MARK: - Integration Extension

extension UnifiedChatInputBar {
    /// Convenience initializer for simple use cases
    init(
        messageText: Binding<String>,
        showingCommandPalette: Binding<Bool>,
        isInputFocused: FocusState<Bool>.Binding,
        onSend: @escaping () -> Void
    ) {
        self._messageText = messageText
        self._showingCommandPalette = showingCommandPalette
        self._isInputFocused = isInputFocused
        self.currentBook = nil
        self.onSend = onSend
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
                onSend: {}
            )
            .padding()
        }
    }
}