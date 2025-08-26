import SwiftUI
import SwiftData
import PhotosUI

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var author = ""
    @State private var isbn = ""
    @State private var genre = ""
    @State private var publicationYear = ""
    @State private var publisher = ""
    @State private var bookDescription = ""
    @State private var totalPages = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var showingImagePicker = false
    
    var isValid: Bool {
        !title.isEmpty && !author.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Book Information") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    TextField("ISBN (Optional)", text: $isbn)
                    TextField("Genre (Optional)", text: $genre)
                    TextField("Publication Year (Optional)", text: $publicationYear)
                        .keyboardType(.numberPad)
                    TextField("Publisher (Optional)", text: $publisher)
                    TextField("Total Pages (Optional)", text: $totalPages)
                        .keyboardType(.numberPad)
                }
                
                Section("Description") {
                    TextEditor(text: $bookDescription)
                        .frame(minHeight: 100)
                }
                
                Section("Cover Image") {
                    if let coverImageData,
                       let uiImage = UIImage(data: coverImageData) {
                        HStack {
                            Spacer()
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                            Spacer()
                        }
                        
                        Button("Change Cover", action: { showingImagePicker = true })
                            .foregroundColor(.blue)
                    } else {
                        Button(action: { showingImagePicker = true }) {
                            HStack {
                                Image(systemName: "photo")
                                Text("Add Cover Image")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBook()
                    }
                    .disabled(!isValid)
                }
            }
            .photosPicker(
                isPresented: $showingImagePicker,
                selection: $selectedImage,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        coverImageData = data
                    }
                }
            }
        }
    }
    
    private func saveBook() {
        let book = Book(
            title: title,
            author: author,
            isbn: isbn.isEmpty ? nil : isbn,
            coverImageData: coverImageData,
            genre: genre.isEmpty ? nil : genre,
            publicationYear: Int(publicationYear),
            publisher: publisher.isEmpty ? nil : publisher,
            description: bookDescription.isEmpty ? nil : bookDescription,
            totalPages: Int(totalPages)
        )
        
        modelContext.insert(book)
        dismiss()
    }
}

#Preview {
    AddBookView()
        .modelContainer(ModelContainer.previewContainer)
}