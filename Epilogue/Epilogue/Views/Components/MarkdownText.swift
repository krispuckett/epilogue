import SwiftUI

struct MarkdownText: View {
    let text: String
    let isUserMessage: Bool
    
    var body: some View {
        if #available(iOS 15.0, *) {
            // Use built-in markdown support for iOS 15+
            Text(attributedString)
                .font(isUserMessage ? 
                      .system(size: 16, weight: .regular, design: .default) :
                      .custom("Georgia", size: 17))
                .foregroundStyle(isUserMessage ? .white : Color(red: 0.98, green: 0.97, blue: 0.96))
                .lineSpacing(isUserMessage ? 2 : 4)
                .tint(DesignSystem.Colors.primaryAccent) // Amber for links
                .fixedSize(horizontal: false, vertical: true) // Ensure full text is displayed
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Fallback for older iOS versions
            Text(text)
                .font(isUserMessage ? 
                      .system(size: 16, weight: .regular, design: .default) :
                      .custom("Georgia", size: 17))
                .foregroundStyle(isUserMessage ? .white : Color(red: 0.98, green: 0.97, blue: 0.96))
                .lineSpacing(isUserMessage ? 2 : 4)
                .fixedSize(horizontal: false, vertical: true) // Ensure full text is displayed
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @available(iOS 15.0, *)
    private var attributedString: AttributedString {
        do {
            // Try native markdown parsing first
            var attributed = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            
            // Apply base styling
            attributed.font = isUserMessage ? 
                .system(size: 16, weight: .regular, design: .default) :
                .custom("Georgia", size: 17)
            attributed.foregroundColor = isUserMessage ? .white : Color(red: 0.98, green: 0.97, blue: 0.96)
            
            // Enhance citation styling [1] [2] etc
            let fullText = String(attributed.characters)
            var searchRange = fullText.startIndex..<fullText.endIndex
            
            while let citationRange = fullText.range(of: #"\[\d+\]"#, options: .regularExpression, range: searchRange) {
                if let attributedRange = Range(citationRange, in: attributed) {
                    attributed[attributedRange].font = .system(size: 13, weight: .medium)
                    attributed[attributedRange].foregroundColor = DesignSystem.Colors.primaryAccent.opacity(0.8)
                    attributed[attributedRange].baselineOffset = 2
                }
                searchRange = citationRange.upperBound..<fullText.endIndex
            }
            
            return attributed
            
        } catch {
            // Fallback to manual parsing if native markdown fails
            return parseCustomMarkdown()
        }
    }
    
    @available(iOS 15.0, *)
    private func parseCustomMarkdown() -> AttributedString {
        var result = AttributedString(text)
        _ = text
        
        // Process bold patterns: **text** or __text__
        result = processBoldPattern(result, pattern: "**", font: isUserMessage ?
            .system(size: 16, weight: .semibold, design: .default) :
            .custom("Georgia-Bold", size: 17))
        
        result = processBoldPattern(result, pattern: "__", font: isUserMessage ?
            .system(size: 16, weight: .semibold, design: .default) :
            .custom("Georgia-Bold", size: 17))
        
        // Process italic patterns: *text* or _text_
        result = processItalicPattern(result, pattern: "*", font: isUserMessage ?
            .system(size: 16, weight: .regular, design: .default).italic() :
            .custom("Georgia-Italic", size: 17))
        
        result = processItalicPattern(result, pattern: "_", font: isUserMessage ?
            .system(size: 16, weight: .regular, design: .default).italic() :
            .custom("Georgia-Italic", size: 17))
        
        // Process citations
        result = processCitations(result)
        
        return result
    }
    
    @available(iOS 15.0, *)
    private func processBoldPattern(_ attributed: AttributedString, pattern: String, font: Font) -> AttributedString {
        var result = attributed
        let text = String(result.characters)
        var searchStartIndex = text.startIndex
        
        while let startRange = text.range(of: pattern, range: searchStartIndex..<text.endIndex) {
            guard let endRange = text.range(of: pattern, range: startRange.upperBound..<text.endIndex) else { break }
            
            let contentStart = startRange.upperBound
            let contentEnd = endRange.lowerBound
            let fullRange = startRange.lowerBound..<endRange.upperBound
            
            if contentStart < contentEnd {
                let content = String(text[contentStart..<contentEnd])
                
                if let attributedFullRange = Range(fullRange, in: result) {
                    result.replaceSubrange(attributedFullRange, with: AttributedString(content))
                    
                    // Find the content in the updated string and apply font
                    let updatedText = String(result.characters)
                    if let contentRange = updatedText.range(of: content),
                       let attributedContentRange = Range(contentRange, in: result) {
                        result[attributedContentRange].font = font
                    }
                }
            }
            
            searchStartIndex = endRange.upperBound
        }
        
        return result
    }
    
    @available(iOS 15.0, *)
    private func processItalicPattern(_ attributed: AttributedString, pattern: String, font: Font) -> AttributedString {
        var result = attributed
        let text = String(result.characters)
        var searchStartIndex = text.startIndex
        
        while let startRange = text.range(of: pattern, range: searchStartIndex..<text.endIndex) {
            // Make sure it's not part of a bold pattern
            if pattern == "*" && startRange.lowerBound > text.startIndex {
                let prevIndex = text.index(before: startRange.lowerBound)
                if text[prevIndex] == "*" {
                    searchStartIndex = startRange.upperBound
                    continue
                }
            }
            
            guard let endRange = text.range(of: pattern, range: startRange.upperBound..<text.endIndex) else { break }
            
            let contentStart = startRange.upperBound
            let contentEnd = endRange.lowerBound
            let fullRange = startRange.lowerBound..<endRange.upperBound
            
            if contentStart < contentEnd {
                let content = String(text[contentStart..<contentEnd])
                
                if let attributedFullRange = Range(fullRange, in: result) {
                    result.replaceSubrange(attributedFullRange, with: AttributedString(content))
                    
                    // Find the content in the updated string and apply font
                    let updatedText = String(result.characters)
                    if let contentRange = updatedText.range(of: content),
                       let attributedContentRange = Range(contentRange, in: result) {
                        result[attributedContentRange].font = font
                    }
                }
            }
            
            searchStartIndex = endRange.upperBound
        }
        
        return result
    }
    
    @available(iOS 15.0, *)
    private func processCitations(_ attributed: AttributedString) -> AttributedString {
        var result = attributed
        let text = String(result.characters)
        var searchRange = text.startIndex..<text.endIndex
        
        while let citationRange = text.range(of: #"\[\d+\]"#, options: .regularExpression, range: searchRange) {
            if let attributedRange = Range(citationRange, in: result) {
                result[attributedRange].font = .system(size: 13, weight: .medium)
                result[attributedRange].foregroundColor = DesignSystem.Colors.primaryAccent.opacity(0.8)
                result[attributedRange].baselineOffset = 2
            }
            searchRange = citationRange.upperBound..<text.endIndex
        }
        
        return result
    }
}

// Preview provider for testing
struct MarkdownText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 20) {
            MarkdownText(
                text: "This is **bold text** and this is *italic text* with a citation [1].",
                isUserMessage: false
            )
            
            MarkdownText(
                text: "Homer's *Iliad* explores themes of **war and honor** [2][3].",
                isUserMessage: false
            )
            
            MarkdownText(
                text: "What do you think about the __Odyssey__?",
                isUserMessage: true
            )
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
