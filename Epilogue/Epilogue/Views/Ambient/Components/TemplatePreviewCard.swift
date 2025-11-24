import SwiftUI
import SwiftData

struct TemplatePreviewCard: View {
    let preview: TemplatePreviewModel
    let onConfirm: () -> Void

    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            headerSection

            // Preview content
            contentPreview

            // Spoiler protection info
            spoilerInfo

            // Actions
            actionButtons
        }
        .padding(20)
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: preview.template.templateType.systemImage)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Text(preview.template.templateType.rawValue.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.2)

                Spacer()
            }

            Text(preview.book.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
    }

    // MARK: - Content Preview

    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let firstSection = preview.template.sections.first {
                Text("Preview")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                ForEach(firstSection.items.prefix(3)) { item in
                    Text("• \(itemPreviewText(item))")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                if firstSection.items.count > 3 {
                    Text("+ \(firstSection.items.count - 3) more")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(DesignSystem.CornerRadius.small)
    }

    // MARK: - Spoiler Info

    private var spoilerInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))

                Text("Only showing info through Chapter \(preview.template.revealedThrough)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text("No spoilers")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showSettings = true
            } label: {
                Text("Settings")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }

            Spacer()

            Button {
                onConfirm()
            } label: {
                Text("Open Template")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(red: 1.0, green: 0.549, blue: 0.259))
                    .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showSettings) {
            TemplateSpoilerSettings(template: preview.template, book: preview.book)
        }
    }

    // MARK: - Helpers

    private func itemPreviewText(_ item: TemplateItem) -> String {
        let content = item.content.components(separatedBy: "\n").first ?? item.content
        return String(content.prefix(60))
    }
}
