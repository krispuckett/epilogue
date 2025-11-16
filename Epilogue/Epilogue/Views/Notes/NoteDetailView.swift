import SwiftUI
import SwiftData

// MARK: - Note Detail View (Reading Mode for Long Notes)
struct NoteDetailView: View {
    let note: Note
    let capturedNote: CapturedNote?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showingDeleteAlert = false

    // EXACTLY LIKE AMBIENT SESSION SUMMARY
    private var minimalGradientBackground: some View {
        ZStack {
            // Permanent ambient gradient background
            AmbientChatGradientView()
                .opacity(0.7)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            // Subtle darkening overlay for better readability
            Color.black.opacity(0.05)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Minimal background
                minimalGradientBackground

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header metadata
                        VStack(alignment: .leading, spacing: 12) {
                            // Date
                            Text(formatDate(note.dateCreated).uppercased())
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .kerning(1.4)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)

                            // Book info
                            if let bookTitle = note.bookTitle {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookTitle.uppercased())
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .kerning(1.0)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                                    if let author = note.author {
                                        Text("by \(author)")
                                            .font(.system(size: 12, weight: .regular, design: .default))
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    }

                                    if let pageNumber = note.pageNumber {
                                        Text("Page \(pageNumber)")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        .padding(.top, 24)
                        .padding(.bottom, 32)

                        // Divider
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.0), location: 0),
                                .init(color: Color.white.opacity(0.08), location: 0.5),
                                .init(color: Color.white.opacity(0.0), location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 0.5)
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        .padding(.bottom, 32)

                        // Main content - optimized for reading
                        Text(note.content)
                            .font(.system(size: 18, weight: .regular, design: .default))
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(9)
                            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                            .padding(.bottom, 60)
                            .textSelection(.enabled)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // Share button
                        ShareLink(item: note.content) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }

                        // Delete button
                        Button {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                    }
                }
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
