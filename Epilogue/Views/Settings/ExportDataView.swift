import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportFormat: DataExportService.ExportFormat = .json
    @State private var selectedBooks: Set<Book> = []
    @State private var includeQuotes = true
    @State private var includeNotes = true
    @State private var includeAISessions = false
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedData: Data?
    @State private var exportedFileName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @Query private var books: [Book]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $exportFormat) {
                        Text("JSON").tag(DataExportService.ExportFormat.json)
                        Text("Markdown").tag(DataExportService.ExportFormat.markdown)
                        Text("CSV").tag(DataExportService.ExportFormat.csv)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text(formatDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Select Books") {
                    if books.isEmpty {
                        Text("No books in library")
                            .foregroundColor(.secondary)
                    } else {
                        Toggle("Select All", isOn: Binding(
                            get: { selectedBooks.count == books.count },
                            set: { selectAll in
                                if selectAll {
                                    selectedBooks = Set(books)
                                } else {
                                    selectedBooks.removeAll()
                                }
                            }
                        ))
                        
                        ForEach(books) { book in
                            HStack {
                                Image(systemName: selectedBooks.contains(book) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedBooks.contains(book) ? .blue : .gray)
                                
                                VStack(alignment: .leading) {
                                    Text(book.title)
                                        .font(.headline)
                                    Text(book.author)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    if let quotesCount = book.quotes?.count, quotesCount > 0 {
                                        Text("\(quotesCount) quotes")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    if let notesCount = book.notes?.count, notesCount > 0 {
                                        Text("\(notesCount) notes")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedBooks.contains(book) {
                                    selectedBooks.remove(book)
                                } else {
                                    selectedBooks.insert(book)
                                }
                            }
                        }
                    }
                }
                
                Section("Include Content") {
                    Toggle("Quotes", isOn: $includeQuotes)
                    Toggle("Notes", isOn: $includeNotes)
                    Toggle("AI Sessions", isOn: $includeAISessions)
                        .disabled(exportFormat == .csv)
                    
                    if exportFormat == .csv && includeAISessions {
                        Text("AI Sessions are not supported in CSV format")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Section {
                    Button(action: performExport) {
                        if isExporting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Exporting...")
                            }
                        } else {
                            Text("Export Data")
                        }
                    }
                    .disabled(selectedBooks.isEmpty || isExporting)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Export Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = exportedData {
                    ShareSheet(
                        activityItems: [ExportFileDocument(data: data, fileName: exportedFileName)],
                        applicationActivities: nil
                    )
                }
            }
            .alert("Export Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var formatDescription: String {
        switch exportFormat {
        case .json:
            return "Machine-readable format, preserves all data structure"
        case .markdown:
            return "Human-readable format, great for documentation"
        case .csv:
            return "Spreadsheet format, easy to import into Excel"
        }
    }
    
    private func performExport() {
        isExporting = true
        
        Task {
            do {
                let scope: DataExportService.ExportScope
                if selectedBooks.count == 1, let book = selectedBooks.first {
                    scope = .singleBook(book)
                } else {
                    scope = .allBooks
                }
                
                let data = try DataExportService.exportData(
                    format: exportFormat,
                    scope: scope,
                    context: modelContext
                )
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: Date())
                
                let extension_: String
                switch exportFormat {
                case .json:
                    extension_ = "json"
                case .markdown:
                    extension_ = "md"
                case .csv:
                    extension_ = "csv"
                }
                
                exportedFileName = "epilogue-export-\(dateString).\(extension_)"
                exportedData = data
                
                await MainActor.run {
                    isExporting = false
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct ExportFileDocument: NSObject, UIActivityItemSource {
    let data: Data
    let fileName: String
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return fileName
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)
        return tempURL
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Epilogue Library Export"
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportDataView()
        .modelContainer(ModelContainer.previewContainer)
}