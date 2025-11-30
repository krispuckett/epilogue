import SwiftUI

// MARK: - View Extension for Conditional Modifiers

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Unified Chat Message
// Shared message type used across ambient mode and chat components

struct UnifiedChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let bookContext: Book?
    let messageType: MessageType

    enum Role {
        case user
        case assistant
    }

    enum MessageType {
        case text
        case note(CapturedNote)
        case noteWithContext(CapturedNote, context: String)
        case quote(CapturedQuote)
        case system
        case contextSwitch
        case transcribing
        case bookRecommendations([BookRecommendation])
        case conversationalResponse(text: String, followUpQuestions: [String])
    }

    // Book recommendation for conversational AI
    struct BookRecommendation: Identifiable {
        let id = UUID()
        let title: String
        let author: String
        let reason: String
        let coverURL: String?
        let isbn: String?
        let purchaseURL: String?

        var amazonURL: String? {
            if let isbn = isbn {
                return "https://www.amazon.com/dp/\(isbn)"
            }
            // Fallback to search URL
            let searchQuery = "\(title) \(author)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "https://www.amazon.com/s?k=\(searchQuery)"
        }
    }

    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date(), bookContext: Book? = nil, messageType: MessageType = .text) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.bookContext = bookContext
        self.messageType = messageType
    }
}

// MARK: - Conversational Response Parsed
/// Result of parsing an AI response for conversational UI

struct ConversationalResponseParsed {
    let cleanedText: String
    let recommendations: [UnifiedChatMessage.BookRecommendation]
    let followUps: [String]
    let hasRecommendations: Bool
}

// MARK: - Ambient Chat Gradient View
// Beautiful theme-aware gradient background for ambient mode

struct AmbientChatGradientView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            // Base color - darker for daybreak to let gradients show
            Color.black

            let colors = themeManager.currentTheme.gradientColors.map {
                themeManager.currentTheme == .daybreak ? $0 : enhanceColor($0)
            }

            // Theme-aware gradient - top (subtle and moody)
            LinearGradient(
                stops: [
                    .init(color: colors[0].opacity(themeManager.currentTheme == .daybreak ? 0.95 : 0.6), location: 0.0),
                    .init(color: colors[1].opacity(themeManager.currentTheme == .daybreak ? 0.85 : 0.45), location: 0.15),
                    .init(color: colors[2].opacity(themeManager.currentTheme == .daybreak ? 0.75 : 0.3), location: 0.3),
                    .init(color: Color.clear, location: 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Theme-aware gradient - bottom (subtle and moody)
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.5),
                    .init(color: colors[2].opacity(themeManager.currentTheme == .daybreak ? 0.65 : 0.3), location: 0.7),
                    .init(color: colors[1].opacity(themeManager.currentTheme == .daybreak ? 0.75 : 0.45), location: 0.85),
                    .init(color: colors[3].opacity(themeManager.currentTheme == .daybreak ? 0.85 : 0.6), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

        }
        .ignoresSafeArea()
    }

    /// Enhance color - vibrant boost for atmospheric ambiance
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Boost vibrancy and brightness for amber/theme colors
        saturation = min(saturation * 1.4, 1.0)  // Boost vibrancy
        brightness = max(brightness, 0.4)         // Minimum brightness

        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
}

// MARK: - Edit Content Overlay
// Keyboard-aware editing overlay for notes/quotes

struct EditContentOverlay: View {
    let originalText: String
    @Binding var editedText: String
    @Binding var isPresented: Bool
    let onSave: () -> Void
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark backdrop - visible like LiquidCommandPalette
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPresented = false
                        SensoryFeedback.light()
                    }

                VStack {
                    Spacer()

                    // Clean input bar - just text field and arrow button
                    HStack(alignment: .bottom, spacing: 12) {
                        // Text input field with the content already loaded
                        TextField("", text: $editedText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.white)
                            .accentColor(DesignSystem.Colors.primaryAccent)
                            .focused($isFocused)
                            .lineLimit(1...8) // Allow vertical expansion
                            .fixedSize(horizontal: false, vertical: true)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(.vertical, 12)
                            .padding(.leading, 16)

                        // Single arrow button for save/submit
                        Button {
                            if editedText != originalText && !editedText.isEmpty {
                                SensoryFeedback.success()
                                onSave()
                                isPresented = false
                            } else if editedText.isEmpty {
                                // If empty, just close
                                SensoryFeedback.light()
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(
                                    editedText != originalText && !editedText.isEmpty
                                        ? DesignSystem.Colors.primaryAccent
                                        : DesignSystem.Colors.textQuaternary
                                )
                                .padding(.trailing, 16)
                                .padding(.vertical, 12)
                        }
                        .disabled(editedText == originalText || editedText.isEmpty)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color(red: 0.12, green: 0.11, blue: 0.105))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .padding(.bottom, keyboardHeight > 0 ? 20 : 30) // Adjust padding when keyboard shown
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
                .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            }
        }
        .ignoresSafeArea(.container, edges: .top) // Only ignore top safe area
        .onAppear {
            // Text is already populated with originalText via binding
            withAnimation(.easeOut(duration: 0.2)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }

            // Subscribe to keyboard notifications
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = keyboardFrame.height
                    }
                }
            }

            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
        }
    }
}

// MARK: - Voice-Responsive Bottom Gradient
// Audio-reactive gradient effect for voice recording

struct VoiceResponsiveBottomGradient: View {
    let colorPalette: ColorPalette?
    let audioLevel: Float
    let isRecording: Bool
    let bookContext: Book?

    @State private var pulsePhase: Double = 0
    @State private var waveOffset: Double = 0

    private var gradientColors: [Color] {
        guard let palette = colorPalette else {
            // Fallback to warm amber gradient
            return [
                DesignSystem.Colors.primaryAccent.opacity(0.6),
                Color(red: 1.0, green: 0.45, blue: 0.2).opacity(0.4),
                Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.2),
                Color.clear
            ]
        }

        // Use enhanced colors from book palette - same enhancement as top gradient
        return [
            enhanceColor(palette.primary).opacity(0.85),
            enhanceColor(palette.secondary).opacity(0.65),
            enhanceColor(palette.accent).opacity(0.4),
            Color.clear
        ]
    }

    /// Enhance color - matches BookAtmosphericGradientView.enhanceColor
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // 1.3x saturation - balanced vibrancy
        saturation = min(saturation * 1.3, 1.0)
        brightness = max(brightness, 0.45)

        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }

    private func gradientHeight(for screenHeight: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = 240 // Slightly lower base

        // Apply logarithmic curve to make it more sensitive to lower volumes
        // This amplifies quiet sounds more than loud ones
        let normalizedAudio = min(audioLevel, 1.0) // Ensure it's capped at 1.0
        let amplifiedLevel = log10(1 + normalizedAudio * 9) // Log curve: more boost at low levels

        let audioBoost = CGFloat(amplifiedLevel) * 200 // Increased multiplier for visibility
        let maxHeight: CGFloat = screenHeight * 0.35 // Cap at 35% of screen
        return min(baseHeight + audioBoost, maxHeight)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()

                // Voice-responsive gradient
                LinearGradient(
                    stops: [
                        .init(color: gradientColors[0], location: 0.0),
                        .init(color: gradientColors[1], location: 0.3),
                        .init(color: gradientColors[2], location: 0.6),
                        .init(color: gradientColors[3], location: 1.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: gradientHeight(for: geometry.size.height))
                .blur(radius: 20)
                .opacity(isRecording ? 1.0 : 0.001) // Pre-rendered at minimal opacity
                .scaleEffect(y: 1.0 + Double(min(log10(1 + audioLevel * 9), 1.0)) * 0.6, anchor: .bottom) // More sensitive scale with log curve
                .animation(.easeInOut(duration: 0.1), value: audioLevel)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRecording)

                // Add subtle wave animation
                .overlay(alignment: .bottom) {
                    if isRecording {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        gradientColors[0].opacity(0.3),
                                        gradientColors[1].opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: 60)
                            .blur(radius: 15)
                            .offset(y: sin(waveOffset) * 10)
                            .animation(
                                .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                                value: waveOffset
                            )
                    }
                }
            }
        }
        .onAppear {
            // Start wave animation
            withAnimation {
                waveOffset = .pi
            }
        }
        .onChange(of: audioLevel) { _, newLevel in
            // Pulse effect on high audio levels
            if newLevel > 0.3 {
                withAnimation(DesignSystem.Animation.easeQuick) {
                    pulsePhase = pulsePhase + 0.5
                }
            }
        }
    }
}
