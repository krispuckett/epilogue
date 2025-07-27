import SwiftUI

// MARK: - Collapsed Navigation Header
struct CollapsedNavigationHeader: View {
    let title: String
    let subtitle: String?
    let coverURL: String?
    @Binding var scrollOffset: CGFloat
    @Environment(\.dismiss) private var dismiss
    
    // Calculate header opacity based on scroll
    private var headerOpacity: Double {
        let threshold: CGFloat = 80
        return Double(min(max(scrollOffset / threshold, 0), 1))
    }
    
    // Calculate scale for cover image
    private var coverScale: CGFloat {
        let maxScale: CGFloat = 1.2
        let stretchOffset = max(-scrollOffset, 0) / 100
        return 1 + stretchOffset * (maxScale - 1)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Blur background that appears on scroll
            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                .opacity(headerOpacity)
                .ignoresSafeArea(edges: .top)
                .frame(height: 110)
            
            // Header content
            VStack(spacing: 0) {
                // Navigation bar area
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    // Collapsed title and subtitle (fade in on scroll)
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .opacity(headerOpacity)
                    
                    Spacer()
                    
                    // Menu button
                    Button {
                        // Menu action
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.top, 44) // Safe area top
                .padding(.bottom, 8)
                
                // Extended header content (visible when not scrolled)
                if scrollOffset < 50 {
                    VStack(spacing: 16) {
                        // Book cover or icon
                        if let coverURL = coverURL,
                           let url = URL(string: coverURL.replacingOccurrences(of: "http://", with: "https://")) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                                        .scaleEffect(coverScale)
                                case .empty:
                                    BookPlaceholder()
                                        .frame(width: 120, height: 180)
                                case .failure(_):
                                    BookPlaceholder()
                                        .frame(width: 120, height: 180)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            // General chat icon
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [
                                            Color.orange.opacity(0.8),
                                            Color.orange.opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 120, height: 120)
                                    .blur(radius: 20)
                                
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white)
                            }
                            .scaleEffect(coverScale)
                        }
                        
                        // Title and subtitle
                        VStack(spacing: 4) {
                            Text(title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            
                            if let subtitle = subtitle {
                                Text(subtitle)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    .opacity(1 - headerOpacity * 1.5) // Fade out faster than header fades in
                    .scaleEffect(1 - headerOpacity * 0.1)
                    .offset(y: -scrollOffset * 0.5) // Parallax effect
                }
            }
        }
    }
}

// MARK: - Book Placeholder
private struct BookPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.1))
            .overlay {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.3))
            }
    }
}

// MARK: - Visual Effect Blur
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - Chat Scroll Offset Preference Key
struct ChatScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Scroll Offset Modifier
struct ScrollOffsetModifier: ViewModifier {
    @Binding var offset: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ChatScrollOffsetPreferenceKey.self,
                            value: -geo.frame(in: .named("scroll")).minY
                        )
                }
            )
            .onPreferenceChange(ChatScrollOffsetPreferenceKey.self) { value in
                offset = value
            }
    }
}