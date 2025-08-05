import SwiftUI

// MARK: - Standardized Input Field Styles for iOS 26

/// Standard text field style for consistency across the app
struct StandardizedTextFieldStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let isFocused: Bool
    
    private var textColor: Color {
        colorScheme == .light ? .black.opacity(0.8) : .white.opacity(0.9)
    }
    
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 16))
            .foregroundStyle(textColor)
            .accentColor(Color(red: 1.0, green: 0.55, blue: 0.26)) // Warm amber accent
    }
}

/// Standard placeholder style
struct StandardizedPlaceholderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(.secondary)
            .font(.system(size: 16))
    }
}

/// Standard input container style with glass effect
struct StandardizedInputContainer: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let isFocused: Bool
    let cornerRadius: CGFloat
    
    private var borderColor: Color {
        if isFocused {
            return Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.5)
        } else {
            return colorScheme == .light ? 
                Color.black.opacity(0.1) : 
                Color.white.opacity(0.1)
        }
    }
    
    func body(content: Content) -> some View {
        content
            .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                borderColor,
                                borderColor.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isFocused ? 1.5 : 0.5
                    )
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            }
            .shadow(
                color: isFocused ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2) : .clear,
                radius: isFocused ? 8 : 0,
                y: 2
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

/// Standard clear button style
struct StandardizedClearButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    colorScheme == .light ? 
                    Color.black.opacity(0.3) : 
                    Color.white.opacity(0.3)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extension for Easy Application
extension View {
    func standardizedTextFieldStyle(isFocused: Bool = false) -> some View {
        self.modifier(StandardizedTextFieldStyle(isFocused: isFocused))
    }
    
    func standardizedPlaceholderStyle() -> some View {
        self.modifier(StandardizedPlaceholderStyle())
    }
    
    func standardizedInputContainer(isFocused: Bool = false, cornerRadius: CGFloat = 22) -> some View {
        self.modifier(StandardizedInputContainer(isFocused: isFocused, cornerRadius: cornerRadius))
    }
}

// MARK: - Standardized Search Field
struct StandardizedSearchField: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(colorScheme == .light ? .black.opacity(0.5) : .white.opacity(0.5))
            
            // Text field
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .standardizedPlaceholderStyle()
                }
                
                TextField("", text: $text)
                    .standardizedTextFieldStyle(isFocused: isFocused)
                    .focused($isFocused)
            }
            
            // Clear button
            if !text.isEmpty {
                StandardizedClearButton {
                    text = ""
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .standardizedInputContainer(isFocused: isFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: text.isEmpty)
    }
}

// MARK: - Standardized Command Input
struct StandardizedCommandInput: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    @FocusState.Binding var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            // Command icon
            Image(systemName: "command")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                .frame(height: 36)
                .padding(.leading, 12)
                .padding(.trailing, 8)
            
            // Text input
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .standardizedPlaceholderStyle()
                        .lineLimit(1)
                }
                
                TextField("", text: $text, axis: .vertical)
                    .standardizedTextFieldStyle(isFocused: isFocused)
                    .focused($isFocused)
                    .lineLimit(1...5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .onSubmit(onSubmit)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            
            // Clear button
            if !text.isEmpty {
                StandardizedClearButton {
                    text = ""
                }
                .padding(.trailing, 12)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(minHeight: 44)
        .standardizedInputContainer(isFocused: isFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: text.isEmpty)
    }
}