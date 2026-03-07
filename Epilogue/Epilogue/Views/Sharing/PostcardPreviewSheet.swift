import SwiftUI

// MARK: - Postcard Preview Sheet
/// Sheet for previewing, customizing, and sharing a literary postcard.

struct PostcardPreviewSheet: View {
    let content: PostcardContent
    let onShare: (UIImage, PostcardTheme) -> Void
    let onDismiss: () -> Void

    @State private var selectedTheme: PostcardTheme = .warm
    @State private var isSquare: Bool = false
    @State private var isGeneratingImage: Bool = false
    @State private var senderName: String = ""

    @AppStorage("userDisplayName") private var savedDisplayName: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview card
                    PostcardPreview(
                        content: content,
                        theme: selectedTheme,
                        senderName: senderName.isEmpty ? nil : senderName,
                        isSquare: isSquare
                    )
                    .animation(.easeInOut(duration: 0.3), value: selectedTheme)
                    .animation(.easeInOut(duration: 0.3), value: isSquare)

                    // Format toggle
                    Picker("Format", selection: $isSquare) {
                        Text("Portrait").tag(false)
                        Text("Square").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Theme selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(PostcardTheme.allCases) { theme in
                                    ThemePill(
                                        theme: theme,
                                        isSelected: selectedTheme == theme
                                    )
                                    .onTapGesture {
                                        selectedTheme = theme
                                        SensoryFeedback.selection()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Sender name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sign as (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Your name", text: $senderName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                    .onAppear {
                        if senderName.isEmpty && !savedDisplayName.isEmpty {
                            senderName = savedDisplayName
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.top)
            }
            .navigationTitle("Share Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        sharePostcard()
                    } label: {
                        if isGeneratingImage {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Share")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isGeneratingImage)
                }
            }
        }
    }

    private func sharePostcard() {
        isGeneratingImage = true

        // Save display name for future use
        if !senderName.isEmpty {
            savedDisplayName = senderName
        }

        Task {
            let image = await renderPostcardToImage()
            await MainActor.run {
                isGeneratingImage = false
                if let image = image {
                    onShare(image, selectedTheme)
                }
            }
        }
    }

    @MainActor
    private func renderPostcardToImage() async -> UIImage? {
        if isSquare {
            let view = ShareableLiteraryPostcardSquare(
                content: content,
                theme: selectedTheme,
                senderName: senderName.isEmpty ? nil : senderName
            )
            return ImageRenderer.renderModern(view: view)
        } else {
            let view = ShareableLiteraryPostcard(
                content: content,
                theme: selectedTheme,
                senderName: senderName.isEmpty ? nil : senderName
            )
            return ImageRenderer.renderModern(view: view)
        }
    }
}

// MARK: - Theme Pill

private struct ThemePill: View {
    let theme: PostcardTheme
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Color preview
            Circle()
                .fill(
                    LinearGradient(
                        colors: theme.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(.white, lineWidth: 2)
                    }
                }
                .shadow(color: theme.gradientColors.first?.opacity(0.4) ?? .clear, radius: 4, x: 0, y: 2)

            // Label
            Text(theme.rawValue)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    PostcardPreviewSheet(
        content: PostcardContent(
            headline: "Finished",
            bookTitle: "The Brothers Karamazov",
            bookAuthor: "Fyodor Dostoevsky",
            bodyText: "What lingers: Alyosha's quiet faith in the face of doubt.",
            coverImageURL: nil,
            momentType: .sessionReflection(reflection: "", bookTitle: "", bookAuthor: "")
        ),
        onShare: { _, _ in },
        onDismiss: {}
    )
}
