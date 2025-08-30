import SwiftUI

struct RecentCommandCard: View {
    let command: RecentCommand
    let opacity: Double
    let scale: Double
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: command.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(command.iconColor.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(command.iconColor.opacity(0.1))
                    .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(command.intentType.capitalized)
                            .font(.system(size: 11))
                            .foregroundStyle(command.iconColor.opacity(0.7))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(DesignSystem.Colors.textQuaternary)
                        
                        Text(command.relativeTime)
                            .font(.system(size: 11))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        
                        if command.count > 1 {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
                            
                            Text("\(command.count)x")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textQuaternary)
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                command.iconColor.opacity(0.2),
                                command.iconColor.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.springStandard, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(opacity)
        .scaleEffect(scale)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }
}

// MARK: - Preview

struct RecentCommandCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 12) {
                RecentCommandCard(
                    command: RecentCommand(
                        text: "Add new note about chapter 5",
                        intentType: "note",
                        timestamp: Date().addingTimeInterval(-300),
                        count: 1
                    ),
                    opacity: 1.0,
                    scale: 1.0,
                    action: {}
                )
                
                RecentCommandCard(
                    command: RecentCommand(
                        text: "Search for quotes about wisdom",
                        intentType: "search",
                        timestamp: Date().addingTimeInterval(-3600),
                        count: 3
                    ),
                    opacity: 0.8,
                    scale: 0.95,
                    action: {}
                )
                
                RecentCommandCard(
                    command: RecentCommand(
                        text: "Lord of the Rings",
                        intentType: "book",
                        timestamp: Date().addingTimeInterval(-7200),
                        count: 1
                    ),
                    opacity: 0.6,
                    scale: 0.9,
                    action: {}
                )
            }
            .padding()
        }
    }
}