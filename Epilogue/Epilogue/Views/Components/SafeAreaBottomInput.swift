import SwiftUI

/// iOS 26 SafeAreaBar modifier that provides proper blur inheritance
struct SafeAreaBarModifier<BarContent: View>: ViewModifier {
    let edge: VerticalEdge
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: () -> BarContent
    
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: edge, alignment: alignment, spacing: spacing) {
                // NO .background modifier - this is critical for iOS 26 blur inheritance
                self.content()
            }
    }
}

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
    /// Apply iOS 26 safeAreaBar pattern for bottom input areas using SwiftUI's native API
    /// This provides the proper blur inheritance for iOS 26
    func bottomBarWithBlur<Content: View>(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat = 0,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        // Use SwiftUI's native safeAreaBar for iOS 26
        self.safeAreaBar(edge: .bottom, alignment: alignment, spacing: spacing) {
            content()
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