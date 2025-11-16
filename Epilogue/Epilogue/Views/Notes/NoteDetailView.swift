import SwiftUI
import SwiftData

// MARK: - Note Detail View (Reading Mode for Long Notes)
struct NoteDetailView: View {
    let note: Note
    let capturedNote: CapturedNote?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var scrollOffset: CGFloat = 0
    @State private var showingDeleteAlert = false

    // Ambient atmospheric background (book colors if available)
    private var atmosphericGradient: some View {
        // Fallback gradient
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.10, blue: 0.08),
                Color(red: 0.08, green: 0.07, blue: 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    var body: some View {
        ZStack {
            // Atmospheric background
            atmosphericGradient

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header metadata
                    VStack(alignment: .leading, spacing: 12) {
                        // Date
                        Text(formatDate(note.dateCreated).uppercased())
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .kerning(1.4)
                            .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.6))

                        // Book info
                        if let bookTitle = note.bookTitle {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bookTitle.uppercased())
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .kerning(1.0)
                                    .foregroundStyle(.white.opacity(0.9))

                                if let author = note.author {
                                    Text("by \(author)")
                                        .font(.system(size: 12, weight: .regular, design: .default))
                                        .foregroundStyle(.white.opacity(0.6))
                                }

                                if let pageNumber = note.pageNumber {
                                    Text("Page \(pageNumber)")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)

                    // Divider
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.0), location: 0),
                            .init(color: Color.white.opacity(0.15), location: 0.5),
                            .init(color: Color.white.opacity(0.0), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                    // Main content - optimized for reading
                    Text(note.content)
                        .font(.system(size: 18, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(9)  // Increased for better readability
                        .padding(.horizontal, 24)
                        .padding(.bottom, 60)
                        .textSelection(.enabled)  // Allow copying
                }
            }
            .scrollIndicators(.hidden)

            // Floating close button (top left)
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .overlay {
                                Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Action buttons
                    HStack(spacing: 12) {
                        // Share button
                        ShareLink(item: note.content) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                                .overlay {
                                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                }
                        }
                        .buttonStyle(.plain)

                        // Delete button
                        Button {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(Color.red.opacity(0.10))
                                .clipShape(Circle())
                                .overlay {
                                    Circle().stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationCornerRadius(DesignSystem.CornerRadius.large)
        .alert("Delete Note?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteNote()
            }
        } message: {
            Text("This note will be permanently deleted.")
        }
    }

    private func deleteNote() {
        if let capturedNote = capturedNote {
            modelContext.delete(capturedNote)
            try? modelContext.save()
        }
        dismiss()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}
