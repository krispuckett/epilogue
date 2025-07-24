import SwiftUI

struct BookContextMenu: View {
    let book: Book
    let sourceRect: CGRect
    @Binding var isPresented: Bool
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var containerOpacity: Double = 0
    @State private var containerScale: CGFloat = 0.8
    @State private var showingCoverPicker = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent backdrop
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissMenu()
                    }
                
                // Positioned popover with iOS 26 style
                VStack(spacing: 0) {
                    // Menu options
                    VStack(spacing: 0) {
                        // Mark as Read/Want to Read
                        ContextMenuButton(
                            icon: book.readingStatus == .finished ? "checkmark.circle.fill" : "checkmark.circle",
                            title: book.readingStatus == .finished ? "Mark as Want to Read" : "Mark as Finished",
                            action: {
                                toggleReadingStatus()
                                dismissMenu()
                            }
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.08))
                        
                        // Share
                        ContextMenuButton(
                            icon: "square.and.arrow.up",
                            title: "Share",
                            action: {
                                shareBook()
                                dismissMenu()
                            }
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.08))
                        
                        // Change Cover
                        ContextMenuButton(
                            icon: "photo",
                            title: "Change Cover",
                            action: {
                                dismissMenu()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingCoverPicker = true
                                }
                            }
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.08))
                        
                        // Delete
                        ContextMenuButton(
                            icon: "trash",
                            title: "Delete from Library",
                            isDestructive: true,
                            action: {
                                deleteBook()
                                dismissMenu()
                            }
                        )
                    }
                }
                .frame(width: 340) // Wider like iOS 26 photos
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(white: 0.11)) // Dark gray background
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
                .scaleEffect(containerScale)
                .opacity(containerOpacity)
                .position(calculatePosition(in: geometry))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                containerOpacity = 1
                containerScale = 1
            }
        }
        .sheet(isPresented: $showingCoverPicker) {
            BookSearchSheet(
                searchQuery: book.title,
                onBookSelected: { newBook in
                    libraryViewModel.updateBookCover(book, newCoverURL: newBook.coverImageURL)
                    showingCoverPicker = false
                }
            )
        }
    }
    
    private func calculatePosition(in geometry: GeometryProxy) -> CGPoint {
        let menuHeight: CGFloat = 220 // Approximate height
        let menuWidth: CGFloat = 340
        let padding: CGFloat = 8 // Smaller padding for closer positioning
        
        // Calculate x position - center on the book
        var x = sourceRect.midX
        
        // Ensure menu doesn't go off screen horizontally
        if x - menuWidth/2 < padding {
            x = menuWidth/2 + padding
        } else if x + menuWidth/2 > geometry.size.width - padding {
            x = geometry.size.width - menuWidth/2 - padding
        }
        
        // Calculate y position - show right at the book
        var y = sourceRect.midY
        
        // If it would go off screen at bottom, adjust upward
        if y + menuHeight/2 > geometry.size.height - 100 {
            y = geometry.size.height - 100 - menuHeight/2
        }
        
        // If it would go off screen at top, adjust downward
        if y - menuHeight/2 < 100 {
            y = 100 + menuHeight/2
        }
        
        return CGPoint(x: x, y: y)
    }
    
    private func dismissMenu() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            containerOpacity = 0
            containerScale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
    
    private func toggleReadingStatus() {
        HapticManager.shared.lightTap()
        let newStatus: ReadingStatus = book.readingStatus == .finished ? .wantToRead : .finished
        libraryViewModel.updateReadingStatus(for: book.id, status: newStatus)
    }
    
    private func shareBook() {
        HapticManager.shared.lightTap()
        if let url = URL(string: "https://books.google.com/books?id=\(book.id)") {
            let activityController = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                activityController.popoverPresentationController?.sourceView = rootViewController.view
                rootViewController.present(activityController, animated: true)
            }
        }
    }
    
    private func deleteBook() {
        HapticManager.shared.warning()
        libraryViewModel.removeBook(book)
    }
}

// Context menu button component
private struct ContextMenuButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                
                Spacer()
            }
            .foregroundStyle(isDestructive ? Color.red : .white)
            .padding(.horizontal, 16)
            .padding(.vertical) // Standard iOS padding
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}