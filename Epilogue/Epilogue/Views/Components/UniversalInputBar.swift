import SwiftUI

// MARK: - Input Context
enum InputContext {
    case library
    case chat(book: Book?)
    case notes
    case bookDetail(book: Book)
    case quickActions
    
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
            return "Search, add books, or capture thoughts..."
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
    
    // Computed properties (exact same as UnifiedChatInputBar)
    private var placeholderText: String {
        return context.placeholderText
    }
    
    private var adaptiveUIColor: Color {
        if let palette = colorPalette {
            return palette.adaptiveUIColor
        } else {
            return Color(red: 1.0, green: 0.55, blue: 0.26)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Main input bar - EXACT copy from UnifiedChatInputBar
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
                        if let onCommandTap = onCommandTap {
                            onCommandTap()
                        } else {
                            showingCommandPalette = true
                        }
                    }
                
                // Text input - using standardized styles
                ZStack(alignment: .leading) {
                    if messageText.isEmpty {
                        Text(placeholderText)
                            .standardizedPlaceholderStyle()
                            .lineLimit(1)
                    }
                    
                    TextField("", text: $messageText, axis: .vertical)
                        .standardizedTextFieldStyle(isFocused: isInputFocused)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .fixedSize(horizontal: false, vertical: true)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onSubmit {
                            if !messageText.isEmpty {
                                onSend()
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                
                // Action buttons
                HStack(spacing: 8) {
                    // Waveform toggle button (always shows waveform)
                    Button {
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
            .frame(minHeight: 44)
            .glassEffect(in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: messageText.isEmpty)
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
                .padding(.horizontal, 16)
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
        withAnimation(.easeInOut(duration: 0.3)) {
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
                    print("Submitted: \(text)")
                },
                onMicrophoneTap: {
                    print("Microphone tapped")
                },
                colorPalette: nil,
                showingCommandPalette: false,
                onCommandPaletteTap: {
                    print("Command palette tapped")
                }
            )
        }
    }
}