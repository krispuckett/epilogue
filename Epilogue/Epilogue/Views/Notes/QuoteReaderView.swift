import SwiftUI
import SwiftData

// MARK: - Quote Reader View (Book-Style Reading Experience)
struct QuoteReaderView: View {
    let note: Note
    let capturedQuote: CapturedQuote?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showingDeleteAlert = false

    // Literary ambient background
    private var atmosphericGradient: some View {
        // Warm sepia-toned gradient for quotes
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.14, blue: 0.10),
                Color(red: 0.12, green: 0.10, blue: 0.08)
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

            // Content - centered like a book page
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    // Opening quotation mark - large and elegant
                    Text("\u{201C}")
                        .font(.custom("Georgia", size: 120))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.25))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 32)
                        .padding(.bottom, -30)

                    // Quote text - Georgia serif for literary feel
                    Text(note.content)
                        .font(.custom("Georgia", size: 22))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(14)  // Book-like line spacing
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                        .textSelection(.enabled)  // Allow copying

                    // Attribution - elegant and understated
                    VStack(alignment: .leading, spacing: 12) {
                        // Horizontal rule
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.clear, location: 0),
                                .init(color: Color.white.opacity(0.2), location: 0.5),
                                .init(color: Color.clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 40)

                        // Author and book info
                        VStack(alignment: .leading, spacing: 6) {
                            if let author = note.author {
                                Text("— \(author)")
                                    .font(.custom("Georgia", size: 16))
                                    .italic()
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                            }

                            if let bookTitle = note.bookTitle {
                                Text(bookTitle)
                                    .font(.system(size: 14, weight: .regular, design: .serif))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                            }

                            if let pageNumber = note.pageNumber {
                                Text("Page \(pageNumber)")
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 60)

                    Spacer(minLength: 60)
                }
            }
            .scrollIndicators(.hidden)

            // Floating controls
            VStack {
                HStack {
                    // Close button
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
                        // Share quote
                        ShareLink(item: formatShareText()) {
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

                        // Delete quote
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
        .alert("Delete Quote?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteQuote()
            }
        } message: {
            Text("This quote will be permanently deleted.")
        }
    }

    // MARK: - Helper Functions
    private func formatShareText() -> String {
        var text = "\"\(note.content)\""

        if let author = note.author {
            text += "\n— \(author)"
        }

        if let bookTitle = note.bookTitle {
            text += "\n\(bookTitle)"
        }

        if let pageNumber = note.pageNumber {
            text += ", Page \(pageNumber)"
        }

        return text
    }

    private func deleteQuote() {
        if let capturedQuote = capturedQuote {
            modelContext.delete(capturedQuote)
            try? modelContext.save()
        }
        dismiss()
    }
}
