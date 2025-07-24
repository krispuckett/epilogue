import SwiftUI

struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var captureText = ""
    @State private var isSearchingBooks = false
    @State private var showBookSearch = false
    @State private var detectedBookQuery = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.05, green: 0.05, blue: 0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Text input field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's on your mind?")
                            .font(.labelLarge)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        TextField("Add a book, note, or quote...", text: $captureText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.bodyLarge)
                            .foregroundStyle(.white)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white.opacity(0.1))
                            }
                            .focused($isTextFieldFocused)
                            .lineLimit(3...6)
                            .onChange(of: captureText) { _, newValue in
                                detectIntent(from: newValue)
                            }
                            .onSubmit {
                                processInput()
                            }
                    }
                    .padding(.horizontal)
                    
                    // Quick action buttons
                    HStack(spacing: 12) {
                        QuickActionButton(
                            icon: "book.closed",
                            label: "Book",
                            color: .blue
                        ) {
                            captureText = "Add "
                            isTextFieldFocused = true
                        }
                        
                        QuickActionButton(
                            icon: "quote.opening",
                            label: "Quote",
                            color: .purple
                        ) {
                            captureText = "Quote: "
                            isTextFieldFocused = true
                        }
                        
                        QuickActionButton(
                            icon: "note.text",
                            label: "Note",
                            color: .green
                        ) {
                            captureText = "Note: "
                            isTextFieldFocused = true
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Action button
                    Button {
                        processInput()
                    } label: {
                        HStack {
                            if isSearchingBooks {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Searching...")
                            } else {
                                Text(getActionButtonText())
                            }
                        }
                        .font(.titleMedium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(captureText.isEmpty ? .gray.opacity(0.3) : .blue)
                        }
                    }
                    .disabled(captureText.isEmpty || isSearchingBooks)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(searchQuery: detectedBookQuery) { book in
                // TODO: Add book to library
                dismiss()
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    // MARK: - Helper Methods
    
    private func detectIntent(from text: String) {
        let lowercased = text.lowercased()
        
        // Detect book-related intents
        if lowercased.starts(with: "add ") ||
           lowercased.starts(with: "reading ") ||
           lowercased.contains(" by ") ||
           lowercased.starts(with: "finished ") {
            // This is likely a book
            detectedBookQuery = extractBookQuery(from: text)
        }
    }
    
    private func extractBookQuery(from text: String) -> String {
        var query = text
        
        // Remove common prefixes
        let prefixes = ["add ", "reading ", "finished ", "book: "]
        for prefix in prefixes {
            if query.lowercased().starts(with: prefix) {
                query = String(query.dropFirst(prefix.count))
                break
            }
        }
        
        return query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getActionButtonText() -> String {
        let lowercased = captureText.lowercased()
        
        if lowercased.starts(with: "quote:") {
            return "Save Quote"
        } else if lowercased.starts(with: "note:") {
            return "Save Note"
        } else if lowercased.starts(with: "add ") || 
                  lowercased.starts(with: "reading ") ||
                  lowercased.contains(" by ") {
            return "Search Books"
        }
        
        return "Add"
    }
    
    private func processInput() {
        let lowercased = captureText.lowercased()
        
        if lowercased.starts(with: "quote:") || lowercased.starts(with: "note:") {
            // Save directly
            saveContent()
        } else if lowercased.starts(with: "add ") || 
                  lowercased.starts(with: "reading ") ||
                  lowercased.contains(" by ") {
            // Search for books
            searchBooks()
        } else {
            // Default to book search
            searchBooks()
        }
    }
    
    private func searchBooks() {
        isSearchingBooks = true
        detectedBookQuery = extractBookQuery(from: captureText)
        
        // Simulate search delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSearchingBooks = false
            showBookSearch = true
        }
    }
    
    private func saveContent() {
        // TODO: Implement saving logic
        dismiss()
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(label)
                    .font(.labelSmall)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

#Preview {
    QuickCaptureSheet()
}