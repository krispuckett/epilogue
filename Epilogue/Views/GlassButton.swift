import SwiftUI

struct GlassButton: View {
    let title: String
    let action: () -> Void
    let tintColor: Color
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(tintColor.opacity(0.15))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(tintColor.opacity(0.3), lineWidth: 1)
                        }
                        .shadow(color: tintColor.opacity(0.3), radius: 6)
                }
        }
        .glassEffect()
    }
}

struct GlassIconButton: View {
    let icon: String
    let action: () -> Void
    let tintColor: Color
    let size: CGFloat
    
    init(icon: String, action: @escaping () -> Void, tintColor: Color, size: CGFloat = 40) {
        self.icon = icon
        self.action = action
        self.tintColor = tintColor
        self.size = size
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size == 40 ? 20 : 16))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(tintColor.opacity(0.15))
                        .overlay {
                            Circle()
                                .strokeBorder(tintColor.opacity(0.3), lineWidth: 1)
                        }
                        .shadow(color: tintColor.opacity(0.3), radius: 6)
                }
        }
        .glassEffect()
    }
}