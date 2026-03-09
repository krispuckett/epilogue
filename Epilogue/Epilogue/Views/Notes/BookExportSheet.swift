import SwiftUI

/// Export a complete book's highlights, notes, questions, and sessions as Markdown.
/// Supports Standard, Obsidian, and Notion formats with live preview.
struct BookExportSheet: View {
    let book: BookModel
    @Environment(\.dismiss) private var dismiss

    @State private var options = MarkdownExporter.ExportOptions()
    @State private var showingShareSheet = false
    @State private var markdownContent = ""
    @State private var filename = ""

    private var itemCount: Int {
        (book.quotes?.count ?? 0) + (book.notes?.count ?? 0) + (book.questions?.count ?? 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                AmbientChatGradientView()
                    .opacity(0.2)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Summary
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text(book.author)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(book.quotes?.count ?? 0) quotes")
                                Text("\(book.notes?.count ?? 0) notes")
                                Text("\(book.questions?.count ?? 0) questions")
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .fill(Color.white.opacity(0.06))
                        )

                        // Preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PREVIEW")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .tracking(1.2)

                            ScrollView {
                                Text(markdownContent)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                            }
                            .frame(height: 280)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }

                        // Options
                        VStack(alignment: .leading, spacing: 16) {
                            Text("INCLUDE")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .tracking(1.2)

                            ExportToggleRow(title: "Page Numbers", isOn: $options.includePageNumber)
                            ExportToggleRow(title: "Dates", isOn: $options.includeDateTime)
                        }

                        // Format
                        VStack(alignment: .leading, spacing: 16) {
                            Text("FORMAT")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .tracking(1.2)

                            HStack(spacing: 12) {
                                FormatPill(title: "Standard", selected: options.format == .standard) {
                                    options.format = .standard
                                }
                                FormatPill(title: "Obsidian", selected: options.format == .obsidian) {
                                    options.format = .obsidian
                                }
                                FormatPill(title: "Notion", selected: options.format == .notion) {
                                    options.format = .notion
                                }
                            }
                        }

                        // Export button
                        Button {
                            showingShareSheet = true
                            SensoryFeedback.success()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Export \(book.title)")
                                    .font(.system(size: 17, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(
                                                DesignSystem.Colors.primaryAccent.opacity(0.3),
                                                lineWidth: 1
                                            )
                                    }
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(itemCount == 0)
                        .opacity(itemCount == 0 ? 0.4 : 1.0)
                        .padding(.top, 8)

                        if itemCount == 0 {
                            Text("No notes, quotes, or questions to export yet.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Export Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        SensoryFeedback.light()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .onChange(of: options) { _, _ in updatePreview() }
            .onAppear {
                updatePreview()
                filename = MarkdownExporter.generateFilename(for: book)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = createTemporaryFile() {
                    BookExportShareSheet(items: [url])
                }
            }
        }
    }

    private func updatePreview() {
        markdownContent = MarkdownExporter.exportBook(book, options: options)
    }

    private func createTemporaryFile() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try markdownContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}

// MARK: - Components

private struct ExportToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DesignSystem.Colors.primaryAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.white.opacity(0.05))
        )
    }
}

private struct FormatPill: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            SensoryFeedback.light()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(selected ? DesignSystem.Colors.primaryAccent.opacity(0.3) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .strokeBorder(
                            selected ? DesignSystem.Colors.primaryAccent.opacity(0.6) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct BookExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
