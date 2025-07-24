import SwiftUI

struct QuickSuggestionsView: View {
    @Binding var commandText: String
    @Environment(\.dismiss) var dismiss
    
    let suggestions = [
        ("Note", "note: ", "Add a quick thought"),
        ("Quote", "\"", "Save a memorable quote"),
        ("Book", "add book ", "Add to your library"),
        ("Search", "search ", "Find in your library")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(suggestions, id: \.0) { title, prefix, description in
                    Button {
                        commandText = prefix
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconForTitle(title))
                                .font(.system(size: 18))
                                .foregroundStyle(colorForTitle(title))
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(description)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .interactiveDismissDisabled(false)
    }
    
    private func iconForTitle(_ title: String) -> String {
        switch title {
        case "Note": return "note.text"
        case "Quote": return "quote.opening"
        case "Book": return "book"
        case "Search": return "magnifyingglass"
        default: return "circle"
        }
    }
    
    private func colorForTitle(_ title: String) -> Color {
        switch title {
        case "Note": return Color(red: 0.4, green: 0.6, blue: 0.9)
        case "Quote": return Color(red: 1.0, green: 0.55, blue: 0.26)
        case "Book": return Color(red: 0.6, green: 0.4, blue: 0.8)
        case "Search": return Color(red: 0.3, green: 0.7, blue: 0.5)
        default: return .gray
        }
    }
}