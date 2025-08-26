import SwiftUI
import SwiftData

struct AddQuoteView: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var quoteText = ""
    @State private var pageNumber = ""
    @State private var chapter = ""
    @State private var notes = ""
    @State private var tags = ""
    @State private var isFavorite = false
    @State private var selectedColor = "yellow"
    
    let highlightColors = ["yellow", "blue", "green", "pink", "purple"]
    
    var isValid: Bool {
        !quoteText.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Quote") {
                    TextEditor(text: $quoteText)
                        .frame(minHeight: 100)
                }
                
                Section("Details") {
                    TextField("Page Number (Optional)", text: $pageNumber)
                        .keyboardType(.numberPad)
                    
                    TextField("Chapter (Optional)", text: $chapter)
                    
                    Toggle("Mark as Favorite", isOn: $isFavorite)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
                
                Section("Highlight Color") {
                    Picker("Color", selection: $selectedColor) {
                        ForEach(highlightColors, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(Color(color))
                                    .frame(width: 20, height: 20)
                                Text(color.capitalized)
                            }
                            .tag(color)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Tags") {
                    TextField("Tags (comma-separated)", text: $tags)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Add Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveQuote()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func saveQuote() {
        let tagsArray = tags.isEmpty ? [] : tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let quote = Quote(
            text: quoteText,
            book: book,
            pageNumber: Int(pageNumber),
            chapter: chapter.isEmpty ? nil : chapter,
            notes: notes.isEmpty ? nil : notes,
            highlightColor: selectedColor,
            tags: tagsArray
        )
        
        quote.isFavorite = isFavorite
        
        modelContext.insert(quote)
        dismiss()
    }
}

#Preview {
    AddQuoteView(book: Book(title: "Sample Book", author: "Sample Author"))
        .modelContainer(ModelContainer.previewContainer)
}