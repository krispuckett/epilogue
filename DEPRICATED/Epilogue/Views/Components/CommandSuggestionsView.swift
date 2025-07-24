import SwiftUI

struct CommandSuggestionsView: View {
    let suggestions: [CommandSuggestion]
    let onSelect: (CommandSuggestion) -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(suggestions.prefix(3)) { suggestion in // Limit to 3 suggestions for compactness
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(suggestion.intent.color)
                            .frame(width: 20)
                        
                        Text(suggestion.text)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "return")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if suggestion.id != suggestions.prefix(3).last?.id {
                    Divider()
                        .background(.white.opacity(0.1))
                        .padding(.horizontal, 14)
                }
            }
        }
        .padding(.vertical, 8)
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .scale(scale: 0.96).combined(with: .opacity)
        ))
    }
}

#Preview {
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.15)
            .ignoresSafeArea()
        
        CommandSuggestionsView(
            suggestions: CommandSuggestion.suggestions(for: "Dune"),
            onSelect: { _ in }
        )
        .padding()
    }
}