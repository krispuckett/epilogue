import SwiftUI
import SwiftData

// MARK: - Compact Note Card for BookDetailView
struct CompactNoteCard: View {
    let note: CapturedNote
    let accentColor: Color
    @State private var isPressed = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button {
            // Navigate to Notes tab with this note highlighted
            NavigationCoordinator.shared.navigateToNote(note)
            SensoryFeedback.light()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Note icon with subtle animation
                Image(systemName: "note.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accentColor.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .glassEffect(in: Circle())
                    .scaleEffect(isPressed ? 0.95 : 1.0)

                VStack(alignment: .leading, spacing: 6) {
                    // Note content
                    Text(note.content ?? "")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Metadata
                    HStack(spacing: 8) {
                        // Date
                        Label {
                            Text((note.timestamp ?? Date()).formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11, weight: .medium))
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.white.opacity(0.5))

                        Spacer()

                        // Chevron
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .padding(12)
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
            if pressing {
                SensoryFeedback.light()
            }
        } perform: {}
        .contextMenu {
            Button {
                // Edit note
                NotificationCenter.default.post(
                    name: Notification.Name("EditNote"),
                    object: note
                )
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                // Share note
                shareNote()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                // Delete note directly
                modelContext.delete(note)
                try? modelContext.save()
                SensoryFeedback.success()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func shareNote() {
        let text = "\(note.content ?? "")\n\n— Note from Epilogue"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// Compact Quote Card variant
struct CompactQuoteCard: View {
    let quote: CapturedQuote
    let accentColor: Color
    @State private var isPressed = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button {
            // Navigate to Notes tab with this quote highlighted
            NavigationCoordinator.shared.navigateToQuote(quote)
            SensoryFeedback.light()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Quote icon
                Image(systemName: "quote.opening")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accentColor.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .glassEffect(in: Circle())
                    .scaleEffect(isPressed ? 0.95 : 1.0)

                VStack(alignment: .leading, spacing: 6) {
                    // Quote text
                    Text(quote.text ?? "")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Metadata
                    HStack(spacing: 8) {
                        // Author if available
                        if let author = quote.author {
                            Text("— \(author)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()

                        // Date
                        Text((quote.timestamp ?? Date()).formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(12)
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
            if pressing {
                SensoryFeedback.light()
            }
        } perform: {}
    }
}