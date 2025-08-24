import SwiftUI

struct BatchBookSearchSheet: View {
    @Binding var bookTitles: [String]
    let onBookSelected: (Book) -> Void
    let onComplete: () -> Void
    
    @State private var currentIndex = 0
    @State private var currentQuery = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if currentIndex < bookTitles.count {
                BookSearchSheet(
                    searchQuery: bookTitles[currentIndex],
                    onBookSelected: { book in
                        onBookSelected(book)
                        
                        // Move to next book
                        currentIndex += 1
                        
                        if currentIndex >= bookTitles.count {
                            // All books processed
                            onComplete()
                            dismiss()
                        } else {
                            // Force refresh by changing the view
                            currentQuery = bookTitles[currentIndex]
                        }
                    }
                )
                .id(currentIndex) // Force view refresh when index changes
            } else {
                EmptyView()
                    .onAppear {
                        onComplete()
                        dismiss()
                    }
            }
        }
    }
}