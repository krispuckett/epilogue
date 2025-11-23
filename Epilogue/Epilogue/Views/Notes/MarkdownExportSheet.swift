import SwiftUI

struct MarkdownExportSheet: View {
    let note: CapturedNote?
    let quote: CapturedQuote?
    let notes: [CapturedNote]
    let quotes: [CapturedQuote]
    @Environment(\.dismiss) private var dismiss

    @State private var options = MarkdownExporter.ExportOptions()
    @State private var showingShareSheet = false
    @State private var markdownContent = "Loading preview..."
    @State private var filename = ""

    init(note: CapturedNote? = nil, quote: CapturedQuote? = nil, notes: [CapturedNote] = [], quotes: [CapturedQuote] = []) {
        self.note = note
        self.quote = quote
        self.notes = notes
        self.quotes = quotes

        print("📄 MarkdownExportSheet init")
        print("  Note: \(note != nil)")
        print("  Quote: \(quote != nil)")
        print("  Notes count: \(notes.count)")
        print("  Quotes count: \(quotes.count)")
    }

    private var isBatchExport: Bool {
        notes.count + quotes.count > 1
    }

    private var totalCount: Int {
        notes.count + quotes.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()

                // Subtle gradient overlay
                AmbientChatGradientView()
                    .opacity(0.2)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Preview Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PREVIEW")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .tracking(1.2)

                            ScrollView {
                                Text(markdownContent)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                            }
                            .frame(height: 320)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }

                        // Include in Export Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("INCLUDE IN EXPORT")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .tracking(1.2)

                            VStack(spacing: 12) {
                                ToggleRow(
                                    title: "Book, Author & Page",
                                    isOn: Binding(
                                        get: { options.includeBook && options.includePageNumber },
                                        set: { value in
                                            options.includeBook = value
                                            options.includePageNumber = value
                                        }
                                    )
                                )

                                ToggleRow(
                                    title: "Date & Time",
                                    isOn: $options.includeDateTime
                                )
                            }
                        }

                        // Format Style Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("FORMAT STYLE")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .tracking(1.2)

                            HStack(spacing: 12) {
                                ExportFormatButton(
                                    title: "Standard",
                                    isSelected: options.format == .standard
                                ) {
                                    withAnimation(DesignSystem.Animation.springStandard) {
                                        options.format = .standard
                                    }
                                    SensoryFeedback.light()
                                }

                                ExportFormatButton(
                                    title: "Obsidian",
                                    isSelected: options.format == .obsidian
                                ) {
                                    withAnimation(DesignSystem.Animation.springStandard) {
                                        options.format = .obsidian
                                    }
                                    SensoryFeedback.light()
                                }

                                ExportFormatButton(
                                    title: "Notion",
                                    isSelected: options.format == .notion
                                ) {
                                    withAnimation(DesignSystem.Animation.springStandard) {
                                        options.format = .notion
                                    }
                                    SensoryFeedback.light()
                                }
                            }
                        }

                        // Export Button
                        Button {
                            showingShareSheet = true
                            SensoryFeedback.success()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Export Notes")
                                    .font(.system(size: 17, weight: .semibold))
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
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isBatchExport ? "Export \(totalCount) Items" : "Export as Markdown")
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
            .onChange(of: options) { _, _ in
                updatePreview()
            }
            .onAppear {
                print("📄 Export sheet appeared")
                print("  Note: \(note != nil)")
                print("  Quote: \(quote != nil)")
                print("  Batch notes: \(notes.count)")
                print("  Batch quotes: \(quotes.count)")
                updatePreview()
                updateFilename()
                print("  Generated markdown length: \(markdownContent.count)")
                print("  Filename: \(filename)")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = createTemporaryMarkdownFile() {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func updatePreview() {
        if isBatchExport {
            markdownContent = MarkdownExporter.exportMultiple(
                notes: notes,
                quotes: quotes,
                options: options
            )
        } else if let note = note {
            markdownContent = MarkdownExporter.exportNote(note, options: options)
        } else if let quote = quote {
            markdownContent = MarkdownExporter.exportQuote(quote, options: options)
        }
    }

    private func updateFilename() {
        if isBatchExport {
            filename = MarkdownExporter.generateBatchFilename(count: totalCount)
        } else if let note = note {
            filename = MarkdownExporter.generateFilename(for: note)
        } else if let quote = quote {
            filename = MarkdownExporter.generateFilename(for: quote)
        }
    }

    private func createTemporaryMarkdownFile() -> URL? {
        updateFilename()

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)

        do {
            try markdownContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error creating temporary file: \(error)")
            return nil
        }
    }
}

// MARK: - Toggle Row Component
private struct ToggleRow: View {
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
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.white.opacity(0.05))
        )
        .onChange(of: isOn) { _, _ in
            SensoryFeedback.light()
        }
    }
}

// MARK: - Export Format Button Component
private struct ExportFormatButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    isSelected ? .white : .white.opacity(0.6)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(
                            isSelected
                                ? DesignSystem.Colors.primaryAccent.opacity(0.3)
                                : Color.white.opacity(0.05)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .strokeBorder(
                            isSelected
                                ? DesignSystem.Colors.primaryAccent.opacity(0.6)
                                : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
