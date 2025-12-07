import SwiftUI

// MARK: - Format Button Component
/// High-quality formatting button with haptic feedback and glass effect
/// Matches Epilogue's design system with Raycast/Linear polish

struct FormatButton: View {
    let icon: String
    let syntax: MarkdownSyntax
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: handleTap) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(foregroundColor)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.85 : 1.0)
        .animation(DesignSystem.Animation.springQuick, value: isPressed)
        .accessibilityLabel(syntax.accessibilityLabel)
        .accessibilityHint(syntax.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    private var foregroundColor: Color {
        if isPressed {
            return DesignSystem.Colors.primaryAccent
        } else {
            return .white.opacity(0.7)
        }
    }

    private func handleTap() {
        // Haptic feedback
        SensoryFeedback.light()

        // Visual feedback
        withAnimation(DesignSystem.Animation.springQuick) {
            isPressed = true
        }

        // Execute action
        action()

        // Reset visual state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(DesignSystem.Animation.springQuick) {
                isPressed = false
            }
        }
    }
}

// MARK: - Icon Mapping for Markdown Syntax
extension MarkdownSyntax {
    var systemIcon: String {
        switch self {
        case .bold:
            return "bold"
        case .italic:
            return "italic"
        case .highlight:
            return "highlighter"
        case .blockquote:
            return "quote.opening"
        case .bulletList:
            return "list.bullet"
        case .numberedList:
            return "list.number"
        case .header1:
            return "textformat.size.larger"
        case .header2:
            return "textformat.size"
        }
    }
}

// MARK: - Preview Provider
struct FormatButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                FormatButton(icon: "bold", syntax: .bold) {
                    print("Bold tapped")
                }

                FormatButton(icon: "italic", syntax: .italic) {
                    print("Italic tapped")
                }

                FormatButton(icon: "highlighter", syntax: .highlight) {
                    print("Highlight tapped")
                }

                FormatButton(icon: "quote.opening", syntax: .blockquote) {
                    print("Quote tapped")
                }
            }

            HStack(spacing: 16) {
                FormatButton(icon: "list.bullet", syntax: .bulletList) {
                    print("Bullet list tapped")
                }

                FormatButton(icon: "list.number", syntax: .numberedList) {
                    print("Numbered list tapped")
                }

                FormatButton(icon: "textformat.size.larger", syntax: .header1) {
                    print("H1 tapped")
                }

                FormatButton(icon: "textformat.size", syntax: .header2) {
                    print("H2 tapped")
                }
            }
        }
        .padding(24)
        .background(DesignSystem.Colors.surfaceBackground)
        .preferredColorScheme(.dark)
    }
}
