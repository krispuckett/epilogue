import SwiftUI
import SwiftData

struct QuoteRowView: View {
    let quote: Quote
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                if quote.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                
                Text(quote.text)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : 3)
                    .animation(.easeInOut, value: isExpanded)
            }
            
            if let notes = quote.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.leading, quote.isFavorite ? 20 : 0)
            }
            
            HStack {
                if let pageNumber = quote.pageNumber {
                    Label("Page \(pageNumber)", systemImage: "book.pages")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let chapter = quote.chapter {
                    Text("• \(chapter)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(quote.dateCreated, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !quote.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(quote.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
        }
    }
}