import SwiftUI

/// iOS 26 compliant bottom input area using safeAreaBar
/// This ensures proper positioning above tab bars and safe areas
struct SafeAreaBottomInput<InputContent: View>: ViewModifier {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    @ViewBuilder let inputContent: () -> InputContent
    
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, alignment: alignment, spacing: spacing) {
                inputContent()
                    .background(.regularMaterial)
            }
    }
}

extension View {
    /// Apply iOS 26 safeAreaBar pattern for bottom input areas
    /// This provides the proper blur inheritance for iOS 26
    func safeAreaBar<Content: View>(
        edge: VerticalEdge = .bottom,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat = 0,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        // Use safeAreaInset with proper material background for iOS 26 blur inheritance
        self.safeAreaInset(edge: edge, alignment: alignment, spacing: spacing) {
            content()
                .background(.bar) // iOS 26 bar material for proper blur
        }
    }
    
    /// Fallback for older iOS versions
    func safeAreaBottomInput<Content: View>(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat = 0,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.safeAreaInset(edge: .bottom, alignment: alignment, spacing: spacing) {
            content()
        }
    }
    
    /// Apply iOS 26 safeAreaBar with glass effect for bottom input areas
    func safeAreaBottomBar<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.safeAreaInset(edge: .bottom, spacing: 0) {
            content()
                .background {
                    // iOS 26 glass effect for bottom bars
                    Rectangle()
                        .fill(.regularMaterial)
                        .ignoresSafeArea(edges: .bottom)
                }
        }
    }
}

/// Example implementation for UniversalInputBar wrapper
struct SafeAreaInputBar: View {
    @Binding var messageText: String
    @Binding var showingCommandPalette: Bool
    @FocusState.Binding var isInputFocused: Bool
    @Binding var isRecording: Bool
    
    let context: InputContext
    let onSend: () -> Void
    let onMicrophoneTap: () -> Void
    let colorPalette: ColorPalette?
    
    var body: some View {
        UniversalInputBar(
            messageText: $messageText,
            showingCommandPalette: $showingCommandPalette,
            isInputFocused: $isInputFocused,
            context: context,
            onSend: onSend,
            onMicrophoneTap: onMicrophoneTap,
            isRecording: $isRecording,
            colorPalette: colorPalette
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background {
            // iOS 26 glass background for input areas
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}