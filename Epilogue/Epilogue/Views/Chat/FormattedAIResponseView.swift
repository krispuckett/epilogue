import SwiftUI

/// A view that properly formats AI responses with paragraphs, links, and better typography
struct FormattedAIResponseView: View {
    let content: String
    let textColor: Color
    
    init(content: String, textColor: Color = .white) {
        self.content = content
        self.textColor = textColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(processedParagraphs, id: \.id) { paragraph in
                paragraphView(for: paragraph)
            }
        }
    }
    
    // MARK: - Paragraph Processing
    
    private struct ProcessedParagraph: Identifiable {
        let id = UUID()
        let type: ParagraphType
        let content: String
        let indent: Int
        
        enum ParagraphType {
            case heading
            case normal
            case bulletPoint
            case numberedList(Int)
            case quote
            case footnote
        }
    }
    
    private var processedParagraphs: [ProcessedParagraph] {
        // First, fix spacing issues around punctuation using regex to avoid breaking URLs
        var fixedContent = content
        
        // Fix missing spaces after punctuation (but not in URLs or numbers)
        fixedContent = fixedContent.replacingOccurrences(
            of: #"([.!?:;,])([A-Z])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        
        // Clean up multiple spaces
        fixedContent = fixedContent.replacingOccurrences(
            of: #"\s{2,}"#,
            with: " ",
            options: .regularExpression
        )
        
        let lines = fixedContent.components(separatedBy: "\n")
        var paragraphs: [ProcessedParagraph] = []
        var currentParagraph = ""
        var listCounter = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines but save current paragraph first
            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    paragraphs.append(ProcessedParagraph(
                        type: .normal,
                        content: currentParagraph,
                        indent: 0
                    ))
                    currentParagraph = ""
                }
                continue
            }
            
            // Check for special formatting
            if trimmed.hasPrefix("##") {
                // Save current paragraph
                if !currentParagraph.isEmpty {
                    paragraphs.append(ProcessedParagraph(
                        type: .normal,
                        content: currentParagraph,
                        indent: 0
                    ))
                    currentParagraph = ""
                }
                // Add heading
                let heading = trimmed.replacingOccurrences(of: "##", with: "").trimmingCharacters(in: .whitespaces)
                paragraphs.append(ProcessedParagraph(
                    type: .heading,
                    content: heading,
                    indent: 0
                ))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") || trimmed.hasPrefix("* ") {
                // Save current paragraph
                if !currentParagraph.isEmpty {
                    paragraphs.append(ProcessedParagraph(
                        type: .normal,
                        content: currentParagraph,
                        indent: 0
                    ))
                    currentParagraph = ""
                }
                // Add bullet point
                let bullet = trimmed
                    .replacingOccurrences(of: "- ", with: "")
                    .replacingOccurrences(of: "• ", with: "")
                    .replacingOccurrences(of: "* ", with: "")
                paragraphs.append(ProcessedParagraph(
                    type: .bulletPoint,
                    content: bullet,
                    indent: countLeadingSpaces(line) / 2
                ))
            } else if let numberMatch = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                // Save current paragraph
                if !currentParagraph.isEmpty {
                    paragraphs.append(ProcessedParagraph(
                        type: .normal,
                        content: currentParagraph,
                        indent: 0
                    ))
                    currentParagraph = ""
                }
                // Add numbered list item
                listCounter += 1
                let listItem = trimmed.replacingCharacters(in: numberMatch, with: "")
                paragraphs.append(ProcessedParagraph(
                    type: .numberedList(listCounter),
                    content: listItem,
                    indent: 0
                ))
            } else if trimmed.hasPrefix(">") {
                // Save current paragraph
                if !currentParagraph.isEmpty {
                    paragraphs.append(ProcessedParagraph(
                        type: .normal,
                        content: currentParagraph,
                        indent: 0
                    ))
                    currentParagraph = ""
                }
                // Add quote
                let quote = trimmed.replacingOccurrences(of: ">", with: "").trimmingCharacters(in: .whitespaces)
                paragraphs.append(ProcessedParagraph(
                    type: .quote,
                    content: quote,
                    indent: 0
                ))
            } else if trimmed.range(of: #"^\[\d+\]"#, options: .regularExpression) != nil {
                // Footnote or reference starting with [1], [2], etc.
                if !currentParagraph.isEmpty {
                    paragraphs.append(ProcessedParagraph(
                        type: .normal,
                        content: currentParagraph,
                        indent: 0
                    ))
                    currentParagraph = ""
                }
                paragraphs.append(ProcessedParagraph(
                    type: .footnote,
                    content: trimmed,
                    indent: 0
                ))
            } else {
                // Continue building paragraph
                if !currentParagraph.isEmpty {
                    currentParagraph += " "
                }
                currentParagraph += trimmed
            }
        }
        
        // Add any remaining paragraph
        if !currentParagraph.isEmpty {
            paragraphs.append(ProcessedParagraph(
                type: .normal,
                content: currentParagraph,
                indent: 0
            ))
        }
        
        // If no paragraphs were created, treat the entire content as one paragraph
        if paragraphs.isEmpty && !content.isEmpty {
            paragraphs.append(ProcessedParagraph(
                type: .normal,
                content: content,
                indent: 0
            ))
        }
        
        return paragraphs
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func paragraphView(for paragraph: ProcessedParagraph) -> some View {
        switch paragraph.type {
        case .heading:
            Text(paragraph.content)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textColor)
                .padding(.top, 4)
                .padding(.bottom, 2)
            
        case .normal:
            FormattedTextView(
                text: paragraph.content,
                textColor: textColor,
                fontSize: 15
            )
            .lineSpacing(4)
            
        case .bulletPoint:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.system(size: 15))
                    .foregroundColor(textColor.opacity(0.7))
                    .padding(.leading, CGFloat(paragraph.indent) * 16)
                
                FormattedTextView(
                    text: paragraph.content,
                    textColor: textColor,
                    fontSize: 15
                )
                .lineSpacing(4)
            }
            
        case .numberedList(let number):
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(.system(size: 15))
                    .foregroundColor(textColor.opacity(0.7))
                    .padding(.leading, CGFloat(paragraph.indent) * 16)
                
                FormattedTextView(
                    text: paragraph.content,
                    textColor: textColor,
                    fontSize: 15
                )
                .lineSpacing(4)
            }
            
        case .quote:
            HStack(spacing: 8) {
                Rectangle()
                    .fill(textColor.opacity(0.3))
                    .frame(width: 3)
                
                FormattedTextView(
                    text: paragraph.content,
                    textColor: textColor.opacity(0.9),
                    fontSize: 15,
                    isItalic: true
                )
                .lineSpacing(4)
            }
            .padding(.vertical, 4)
            
        case .footnote:
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                    .background(textColor.opacity(0.2))
                    .padding(.vertical, 4)
                
                FormattedTextView(
                    text: paragraph.content,
                    textColor: textColor.opacity(0.7),
                    fontSize: 13
                )
            }
            .padding(.top, 8)
        }
    }
    
    private func countLeadingSpaces(_ text: String) -> Int {
        var count = 0
        for char in text {
            if char == " " {
                count += 1
            } else {
                break
            }
        }
        return count
    }
}

// MARK: - Formatted Text View with Link Support

struct FormattedTextView: View {
    let text: String
    let textColor: Color
    let fontSize: CGFloat
    let isItalic: Bool
    
    init(text: String, textColor: Color = .white, fontSize: CGFloat = 15, isItalic: Bool = false) {
        self.text = text
        self.textColor = textColor
        self.fontSize = fontSize
        self.isItalic = isItalic
    }
    
    var body: some View {
        let attributedString = processText()
        
        Text(attributedString)
            .font(.system(size: fontSize, weight: .regular))
            .italic(isItalic)
            .foregroundColor(textColor)
            .tint(DesignSystem.Colors.primaryAccent) // For links
    }
    
    private func processText() -> AttributedString {
        var workingText = text
        var attributedString = AttributedString(text)
        
        // Process bold text first (**text**)
        workingText = processInlineMarkdown(
            text: workingText,
            pattern: #"\*\*([^*]+)\*\*"#,
            replacement: "$1",
            attributes: { str in
                str.font = .system(size: fontSize, weight: .semibold)
                return str
            },
            into: &attributedString
        )
        
        // Process italic text (*text* or _text_) - but not bold
        workingText = processInlineMarkdown(
            text: workingText,
            pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#,
            replacement: "$1",
            attributes: { str in
                str.font = .system(size: fontSize).italic()
                return str
            },
            into: &attributedString
        )
        
        // Also handle underscore italics
        workingText = processInlineMarkdown(
            text: workingText,
            pattern: #"_([^_]+)_"#,
            replacement: "$1",
            attributes: { str in
                str.font = .system(size: fontSize).italic()
                return str
            },
            into: &attributedString
        )
        
        // Process links [text](url)
        if let linkRanges = findMarkdownRanges(pattern: #"\[([^\]]+)\]\(([^\)]+)\)"#, in: text) {
            for range in linkRanges {
                if let attrRange = Range(range, in: attributedString) {
                    let linkText = String(text[range])
                    if let match = linkText.firstMatch(of: /\[([^\]]+)\]\(([^\)]+)\)/) {
                        let displayText = String(match.1)
                        let urlString = String(match.2)
                        
                        var linkAttr = AttributedString(displayText)
                        if let url = URL(string: urlString) {
                            linkAttr.link = url
                            linkAttr.foregroundColor = DesignSystem.Colors.primaryAccent
                            linkAttr.underlineStyle = .single
                        }
                        attributedString.replaceSubrange(attrRange, with: linkAttr)
                    }
                }
            }
        }
        
        return attributedString
    }
    
    private func processInlineMarkdown(
        text: String,
        pattern: String,
        replacement: String,
        attributes: (inout AttributedString) -> AttributedString,
        into attributedString: inout AttributedString
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var result = text
        for match in matches.reversed() {
            if let range = Range(match.range, in: text) {
                let matchText = String(text[range])
                let cleanedText = regex.stringByReplacingMatches(
                    in: matchText,
                    options: [],
                    range: NSRange(location: 0, length: (matchText as NSString).length),
                    withTemplate: replacement
                )
                
                // Apply attributes to the cleaned text in attributedString
                if let attrRange = attributedString.range(of: matchText) {
                    var replacement = AttributedString(cleanedText)
                    replacement = attributes(&replacement)
                    attributedString.replaceSubrange(attrRange, with: replacement)
                }
                
                result = result.replacingOccurrences(of: matchText, with: cleanedText)
            }
        }
        
        return result
    }
    
    private func findMarkdownRanges(pattern: String, in text: String) -> [Range<String.Index>]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        
        return matches.compactMap { match in
            Range(match.range, in: text)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            FormattedAIResponseView(
                content: """
                ## About Homer
                
                Homer is the ancient Greek poet traditionally credited with composing The Odyssey, as well as The Iliad.
                
                Here are some key facts about Homer:
                
                • He likely lived around the 8th century BCE
                • His works are foundational to Greek literature
                • The exact details of his life remain mysterious
                
                1. His epic poems were originally oral compositions
                2. They were passed down through generations
                3. Eventually they were written down
                
                > "Sing to me of the man, Muse, the man of twists and turns driven time and again off course"
                
                The Odyssey tells the story of **Odysseus** and his *ten-year journey* home after the Trojan War.
                
                [1] For more information, see [Wikipedia](https://en.wikipedia.org/wiki/Homer)
                [2] Classical sources suggest various birthplaces
                """
            )
            .padding()
            .background(Color.black)
        }
    }
    .preferredColorScheme(.dark)
}