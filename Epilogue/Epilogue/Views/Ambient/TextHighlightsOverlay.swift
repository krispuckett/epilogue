import SwiftUI

// MARK: - Text Highlights Overlay
/// Liquid Glass text highlights that appear over live camera feed
/// Shows recognized text blocks with beautiful translucent overlays

struct TextHighlightsOverlay: View {
    let paragraphs: [TextBlock]
    let selected: TextBlock?
    let onSelect: (TextBlock) -> Void

    var body: some View {
        GeometryReader { geometry in
            ForEach(paragraphs) { paragraph in
                let frame = convertToScreen(paragraph.bounds, in: geometry.size)

                Button {
                    onSelect(paragraph)
                } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            selected?.id == paragraph.id
                                ? Color.orange.opacity(0.8)
                                : Color.white.opacity(0.4),
                            lineWidth: selected?.id == paragraph.id ? 3 : 2
                        )
                        .glassEffect(
                            .regular.tint(
                                selected?.id == paragraph.id
                                    ? .orange.opacity(0.15)
                                    : .white.opacity(0.08)
                            ),
                            in: .rect(cornerRadius: 8)
                        )
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .scaleEffect(selected?.id == paragraph.id ? 1.02 : 1.0)
                        .shadow(
                            color: selected?.id == paragraph.id
                                ? .orange.opacity(0.3)
                                : .clear,
                            radius: 12,
                            y: 4
                        )
                        .animation(
                            .spring(response: 0.25, dampingFraction: 0.75),
                            value: selected?.id
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .allowsHitTesting(true)
    }

    private func convertToScreen(_ normalizedRect: CGRect, in size: CGSize) -> CGRect {
        // Convert Vision's normalized coordinates (0-1) to screen coordinates
        // Vision uses bottom-left origin, SwiftUI uses top-left
        CGRect(
            x: normalizedRect.minX * size.width,
            y: (1 - normalizedRect.maxY) * size.height,  // Flip Y axis
            width: normalizedRect.width * size.width,
            height: normalizedRect.height * size.height
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        TextHighlightsOverlay(
            paragraphs: [
                TextBlock(
                    text: "Example paragraph 1",
                    bounds: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.1),
                    confidence: 0.95
                ),
                TextBlock(
                    text: "Example paragraph 2",
                    bounds: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.15),
                    confidence: 0.92
                )
            ],
            selected: nil,
            onSelect: { _ in }
        )
    }
}
