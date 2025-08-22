import SwiftUI

// Temporary CommandPaletteView - will be replaced with full implementation
struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @Binding var selectedBook: Book?
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    var body: some View {
        NavigationStack {
            List(libraryViewModel.books) { book in
                Button {
                    selectedBook = book
                    isPresented = false
                } label: {
                    HStack {
                        if let coverURL = book.coverImageURL {
                            SharedBookCoverView(coverURL: coverURL, width: 40, height: 60)
                        }
                        VStack(alignment: .leading) {
                            Text(book.title)
                                .font(.headline)
                            Text(book.author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Book")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}