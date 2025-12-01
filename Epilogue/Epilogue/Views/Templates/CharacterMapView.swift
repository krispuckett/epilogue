import SwiftUI
import SwiftData

struct CharacterMapView: View {
    let book: Book
    @Bindable var template: GeneratedTemplate

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var expandedItems: Set<UUID> = []
    @State private var showSettings = false
    @State private var updateRecommendation: UpdateRecommendation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                // Characters
                charactersSection

                Spacer(minLength: 40)

                // Spoiler protection footer
                spoilerProtectionSection

                // Update prompt if available
                if let recommendation = updateRecommendation {
                    updatePromptSection(recommendation)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 20)
        }
        .background(Color.black)
        .navigationTitle("Character Map")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }

                    Button(role: .destructive) {
                        deleteTemplate()
                    } label: {
                        Label("Delete Template", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            TemplateSpoilerSettings(template: template, book: book)
        }
        .task {
            await checkForUpdates()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book.title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            Text("Through Chapter \(template.revealedThrough)")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Characters Section

    private var charactersSection: some View {
        ForEach(Array(template.sections.first?.items.enumerated() ?? [].enumerated()), id: \.element.id) { index, item in
            characterCard(item: item, index: index + 1)
        }
    }

    private func characterCard(item: TemplateItem, index: Int) -> some View {
        let isExpanded = expandedItems.contains(item.id)

        return VStack(spacing: 0) {
            // Collapsed header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedItems.remove(item.id)
                    } else {
                        expandedItems.insert(item.id)
                    }
                }
            } label: {
                HStack {
                    Text(String(format: "%02d", index))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text(characterName(from: item.content))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(16)
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    Text(characterContent(from: item.content))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(4)

                    // User note section
                    if let userNote = item.userNote {
                        Divider()
                            .background(Color.white.opacity(0.1))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOUR NOTE")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .tracking(1.2)

                            Text(userNote)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    } else {
                        Button {
                            // Add note
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Your Note")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                        }
                    }
                }
                .padding(16)
                .padding(.top, -16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color.white.opacity(0.02))
                .glassEffect()
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Spoiler Protection Section

    private var spoilerProtectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                Spacer()
            }

            Text("SPOILER PROTECTION")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            Text("Showing through Chapter \(template.revealedThrough)")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))

            Text("Created \(template.createdDate.formatted(.relative(presentation: .named)))")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Update Prompt Section

    private func updatePromptSection(_ recommendation: UpdateRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("NEW CONTENT AVAILABLE")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.2)

                Text(recommendation.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Button {
                Task {
                    await updateToNewBoundary(recommendation)
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Update to Chapter \(recommendation.newBoundary)")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color(red: 1.0, green: 0.549, blue: 0.259))
                .cornerRadius(10)
                .foregroundStyle(.black)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func characterName(from content: String) -> String {
        content.components(separatedBy: "\n").first ?? "Unknown"
    }

    private func characterContent(from content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Actions

    private func checkForUpdates() async {
        guard let enrichment = book.getEnrichment(context: modelContext) else { return }

        let manager = TemplateUpdateManager(modelContext: modelContext)
        updateRecommendation = manager.checkForUpdate(template, book: book, enrichment: enrichment)
    }

    private func updateToNewBoundary(_ recommendation: UpdateRecommendation) async {
        guard let enrichment = book.getEnrichment(context: modelContext) else { return }

        let manager = TemplateUpdateManager(modelContext: modelContext)

        do {
            try await manager.updateTemplate(
                template,
                book: book,
                enrichment: enrichment,
                toChapter: recommendation.newBoundary
            )
            updateRecommendation = nil
        } catch {
            // Handle error
            print("Failed to update template: \(error)")
        }
    }

    private func deleteTemplate() {
        modelContext.delete(template)
        try? modelContext.save()
        dismiss()
    }
}
