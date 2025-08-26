import SwiftUI
import SwiftData

struct AddNoteView: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var content = ""
    @State private var pageReference = ""
    @State private var chapterReference = ""
    @State private var tags = ""
    @State private var isPinned = false
    
    var isValid: Bool {
        !title.isEmpty && !content.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Title", text: $title)
                    
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }
                
                Section("References") {
                    TextField("Page Number (Optional)", text: $pageReference)
                        .keyboardType(.numberPad)
                    
                    TextField("Chapter (Optional)", text: $chapterReference)
                    
                    Toggle("Pin this note", isOn: $isPinned)
                }
                
                Section("Tags") {
                    TextField("Tags (comma-separated)", text: $tags)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func saveNote() {
        let tagsArray = tags.isEmpty ? [] : tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let note = Note(
            title: title,
            content: content,
            book: book,
            tags: tagsArray,
            pageReference: Int(pageReference),
            chapterReference: chapterReference.isEmpty ? nil : chapterReference
        )
        
        note.isPinned = isPinned
        
        modelContext.insert(note)
        dismiss()
    }
}

#Preview {
    AddNoteView(book: Book(title: "Sample Book", author: "Sample Author"))
        .modelContainer(ModelContainer.previewContainer)
}