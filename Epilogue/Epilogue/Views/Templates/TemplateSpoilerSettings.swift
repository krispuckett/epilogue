import SwiftUI
import SwiftData

struct TemplateSpoilerSettings: View {
    @Bindable var template: GeneratedTemplate
    let book: Book

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: UpdateMode
    @State private var isUpdating = false

    init(template: GeneratedTemplate, book: Book) {
        self.template = template
        self.book = book
        self._selectedMode = State(initialValue: template.updateModeValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Mode selection
                    modeSection

                    // Current status
                    statusSection

                    Spacer(minLength: 40)

                    // Update now button
                    updateNowSection

                    // Delete
                    deleteSection
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, 20)
            }
            .background(Color.black)
            .navigationTitle("Spoiler Protection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                }
            }
        }
    }

    // MARK: - Mode Section

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MODE")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            ForEach([UpdateMode.conservative, UpdateMode.current, UpdateMode.manual], id: \.self) { mode in
                modeOption(mode)
            }
        }
    }

    private func modeOption(_ mode: UpdateMode) -> some View {
        Button {
            selectedMode = mode
            let manager = TemplateUpdateManager(modelContext: modelContext)
            manager.changeUpdateMode(template, to: mode)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedMode == mode ? "circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        selectedMode == mode
                            ? Color(red: 1.0, green: 0.549, blue: 0.259)
                            : DesignSystem.Colors.textSecondary
                    )
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(modeName(mode))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))

                    Text(modeDescription(mode))
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .fill(Color.white.opacity(selectedMode == mode ? 0.05 : 0.02))
                    .glassEffect()
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .strokeBorder(
                        selectedMode == mode
                            ? Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.3)
                            : Color.white.opacity(0.1),
                        lineWidth: selectedMode == mode ? 1.0 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 12) {
                statusRow(label: "Current Progress", value: "Chapter \(inferredChapter)")
                statusRow(label: "Template Shows", value: "Chapter \(template.revealedThrough)")
                statusRow(label: "Created", value: template.createdDate.formatted(.relative(presentation: .named)))
                statusRow(label: "Last Updated", value: template.lastUpdated.formatted(.relative(presentation: .named)))
            }

            Divider()
                .background(Color.white.opacity(0.1))
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Update Now Section

    private var updateNowSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MANUAL UPDATE")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            if canUpdate {
                Button {
                    Task {
                        await updateNow()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isUpdating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.black)
                        } else {
                            Text("Update to Chapter \(inferredChapter)")
                                .font(.system(size: 14, weight: .medium))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color(red: 1.0, green: 0.549, blue: 0.259))
                    .cornerRadius(10)
                    .foregroundStyle(.black)
                }
                .disabled(isUpdating)
            } else {
                Text("Template is up to date")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(role: .destructive) {
            modelContext.delete(template)
            try? modelContext.save()
            dismiss()
        } label: {
            HStack {
                Spacer()
                Text("Delete Template")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.1))
            .cornerRadius(10)
            .foregroundStyle(.red)
        }
    }

    // MARK: - Helpers

    private func modeName(_ mode: UpdateMode) -> String {
        switch mode {
        case .conservative:
            return "Conservative (recommended)"
        case .current:
            return "Current"
        case .manual:
            return "Manual updates only"
        }
    }

    private func modeDescription(_ mode: UpdateMode) -> String {
        switch mode {
        case .conservative:
            return "Shows 1 chapter behind your progress"
        case .current:
            return "Shows exactly your current chapter"
        case .manual:
            return "You choose when to reveal more"
        }
    }

    private var inferredChapter: Int {
        let progress = book.readingProgress
        let percent = progress.percentComplete
        guard let enrichment = book.getEnrichment(context: modelContext) else {
            return Int(percent * 30) // Fallback estimate
        }
        return Int(percent * Double(enrichment.totalChapters))
    }

    private var canUpdate: Bool {
        inferredChapter > template.revealedThrough
    }

    // MARK: - Actions

    private func updateNow() async {
        isUpdating = true
        defer { isUpdating = false }

        guard let enrichment = book.getEnrichment(context: modelContext) else { return }

        let manager = TemplateUpdateManager(modelContext: modelContext)

        do {
            try await manager.updateTemplate(
                template,
                book: book,
                enrichment: enrichment,
                toChapter: inferredChapter
            )
        } catch {
            print("Failed to update: \(error)")
        }
    }
}
