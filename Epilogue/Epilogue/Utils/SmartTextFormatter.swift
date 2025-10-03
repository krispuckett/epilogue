import SwiftUI

/// Smart text formatter that detects content type and applies appropriate styling
struct SmartFormattedText: View {
    let text: String
    let isUser: Bool

    var body: some View {
        if isPoem {
            poemLayout
        } else if isList {
            listLayout
        } else if hasCodeBlock {
            codeLayout
        } else {
            standardLayout
        }
    }

    // MARK: - Content Detection

    private var isPoem: Bool {
        let lines = text.split(separator: "\n")

        // Poems have short lines, often rhyming patterns, specific structure
        let avgLineLength = lines.reduce(0) { $0 + $1.count } / max(lines.count, 1)
        let hasShortLines = avgLineLength < 60
        let hasMultipleLines = lines.count >= 4

        // Check for poem indicators
        let poemKeywords = ["verse", "stanza", "rhyme", "meter", "poem"]
        let hasPoemContext = poemKeywords.contains { text.lowercased().contains($0) }

        // Check for typical poem structure (indentation, line breaks)
        let hasPoetryStructure = lines.filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }.count > 0

        return (hasShortLines && hasMultipleLines) || hasPoemContext || hasPoetryStructure
    }

    private var isList: Bool {
        let listMarkers = ["- ", "• ", "* ", "1.", "2.", "3."]
        return listMarkers.contains { text.contains($0) }
    }

    private var hasCodeBlock: Bool {
        text.contains("```") || text.contains("    ") // code blocks or indented code
    }

    // MARK: - Layout Styles

    @ViewBuilder
    private var poemLayout: some View {
        VStack(spacing: 0) {
            Text(extractPoemContent())
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .tracking(0.3)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 24)

            // Attribution or context if present
            if let context = extractPoemContext() {
                Text(context)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var listLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(extractListItems().enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.marker)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 20, alignment: .leading)

                    Text(item.content)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var codeLayout: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var standardLayout: some View {
        Text(text)
            .font(.system(size: 17, weight: .regular, design: .default))
            .foregroundStyle(.white.opacity(0.9))
            .lineSpacing(6)
            .tracking(0.2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }

    // MARK: - Content Extraction

    private func extractPoemContent() -> String {
        let lines = text.split(separator: "\n")

        // Find where the poem actually starts (skip intro text)
        var poemLines: [String] = []
        var foundPoem = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines before poem starts
            if !foundPoem && trimmed.isEmpty {
                continue
            }

            // Check if this looks like poem content (short line, no colons)
            if trimmed.count > 0 && trimmed.count < 80 && !trimmed.contains(":") {
                foundPoem = true
                poemLines.append(trimmed)
            } else if foundPoem && trimmed.isEmpty {
                // Empty line within poem
                poemLines.append("")
            } else if foundPoem && (trimmed.starts(with: "Key points") || trimmed.contains("emphasizes")) {
                // End of poem, context starts
                break
            }
        }

        return poemLines.joined(separator: "\n")
    }

    private func extractPoemContext() -> String? {
        let lines = text.split(separator: "\n")

        // Find context/analysis after the poem
        var contextLines: [String] = []
        var foundContext = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "Key points") || trimmed.contains("emphasizes") || trimmed.contains("contrasts") {
                foundContext = true
            }

            if foundContext && !trimmed.isEmpty {
                contextLines.append(trimmed)
            }
        }

        return contextLines.isEmpty ? nil : contextLines.joined(separator: "\n")
    }

    private func extractListItems() -> [(marker: String, content: String)] {
        let lines = text.split(separator: "\n")
        var items: [(marker: String, content: String)] = []

        for line in lines {
            let trimmed = String(line.trimmingCharacters(in: .whitespaces))

            if trimmed.starts(with: "- ") {
                let content = String(trimmed.dropFirst(2))
                items.append(("•", content))
            } else if trimmed.starts(with: "* ") {
                let content = String(trimmed.dropFirst(2))
                items.append(("•", content))
            } else if trimmed.starts(with: "• ") {
                let content = String(trimmed.dropFirst(2))
                items.append(("•", content))
            } else if let range = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let marker = String(trimmed[range]).trimmingCharacters(in: .whitespaces)
                let content = String(trimmed[range.upperBound...])
                items.append((marker, content))
            }
        }

        return items
    }
}