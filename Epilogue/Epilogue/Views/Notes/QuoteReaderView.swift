import SwiftUI
import SwiftData

// MARK: - Quote Reader View (Book-Style Reading Experience)
struct QuoteReaderView: View {
    let note: Note
    let capturedQuote: CapturedQuote?
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
                        // Share quote
                        ShareLink(item: formatShareText()) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }

                        // Delete quote
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
