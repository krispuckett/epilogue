import SwiftUI
import SwiftData
import PhotosUI

struct EditBookView: View {
    @Bindable var book: Book
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImage: PhotosPickerItem?
    @State private var showingImagePicker = false
    @State private var rating: Int?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Book Information") {
                    TextField("Title", text: $book.title)
                    TextField("Author", text: $book.author)
                    TextField("ISBN", text: Binding(
                        get: { book.isbn ?? "" },
                        set: { book.isbn = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Genre", text: Binding(
                        get: { book.genre ?? "" },
                        set: { book.genre = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Publisher", text: Binding(
                        get: { book.publisher ?? "" },
                        set: { book.publisher = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section("Reading Progress") {
                    if let totalPages = book.totalPages {
                        TextField("Current Page", value: Binding(
                            get: { book.currentPage ?? 0 },
                            set: { book.currentPage = $0 }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        
                        Text("of \(totalPages) pages")
                            .foregroundColor(.secondary)
                        
                        Slider(value: $book.readingProgress, in: 0...1)
                        Text("\(book.progressPercentage)% complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        TextField("Total Pages", value: Binding(
                            get: { book.totalPages ?? 0 },
                            set: { book.totalPages = $0 == 0 ? nil : $0 }
                        ), format: .number)
                        .keyboardType(.numberPad)
                    }
                }
                
                Section("Rating") {
                    HStack {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= (book.rating ?? 0) ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    if book.rating == star {
                                        book.rating = nil
                                    } else {
                                        book.rating = star
                                    }
                                }
                        }
                    }
                }
                
                Section("Description") {
                    TextEditor(text: Binding(
                        get: { book.bookDescription ?? "" },
                        set: { book.bookDescription = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 100)
                }
                
                Section("Cover Image") {
                    if let coverImageData = book.coverImageData,
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
                        
                        Button("Remove Cover", role: .destructive) {
                            book.coverImageData = nil
                        }
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
            .navigationTitle("Edit Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
                        book.coverImageData = data
                    }
                }
            }
        }
    }
}

#Preview {
    EditBookView(book: Book(title: "Sample Book", author: "Sample Author"))
        .modelContainer(ModelContainer.previewContainer)
}