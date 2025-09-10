import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Optimized Library Grid with Virtualization
struct OptimizedLibraryGrid: View {
    let books: [Book]
    let viewModel: LibraryViewModel
    let highlightedBookId: UUID?
    let onChangeCover: (Book) -> Void
    
    @State private var draggedBook: Book?
    @State private var dragOffset: CGSize = .zero
    @State private var targetIndex: Int?
    @State private var isLongPressing = false
    @Namespace private var gridAnimation
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 32) {
                    ForEach(Array(books.enumerated()), id: \.element.localId) { index, book in
                        ZStack {
                            // Placeholder for dragged item
                            if draggedBook?.id == book.id {
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 250)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                            .strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.5), lineWidth: 2)
                                    )
                            } else {
                                OptimizedGridItem(
                                    book: book,
                                    viewModel: viewModel,
                                    highlightedBookId: highlightedBookId,
                                    onChangeCover: onChangeCover,
                                    isDraggable: viewModel.isReorderMode,
                                    isBeingDragged: draggedBook?.id == book.id
                                )
                                .opacity(draggedBook?.id == book.id ? 0.01 : 1)
                                .scaleEffect(targetIndex == index && draggedBook != nil ? 1.05 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: targetIndex)
                                .draggable(book) {
                                    DragPreview(book: book, viewModel: viewModel)
                                        .onAppear {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                draggedBook = book
                                            }
                                        }
                                }
                                .dropDestination(for: Book.self) { items, location in
                                    guard let droppedBook = items.first,
                                          let fromIndex = books.firstIndex(where: { $0.id == droppedBook.id }),
                                          let toIndex = books.firstIndex(where: { $0.id == book.id }) else {
                                        return false
                                    }
                                    
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        viewModel.moveBook(fromIndex: fromIndex, toIndex: toIndex)
                                    }
                                    return true
                                } isTargeted: { isTargeted in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        targetIndex = isTargeted ? index : nil
                                    }
                                }
                            }
                        }
                        .id(book.localId)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                        .materialize(order: index)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
        }
        .onDrop(of: [.text], delegate: BookDropDelegate(
            draggedBook: $draggedBook,
            targetIndex: $targetIndex
        ))
    }
}

// MARK: - Drag Preview
struct DragPreview: View {
    let book: Book
    let viewModel: LibraryViewModel
    
    var body: some View {
        BookCard(book: book)
            .environmentObject(viewModel)
            .frame(width: 150, height: 225)
            .scaleEffect(1.1)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .strokeBorder(DesignSystem.Colors.primaryAccent, lineWidth: 2)
            )
    }
}

// MARK: - Drop Delegate
struct BookDropDelegate: DropDelegate {
    @Binding var draggedBook: Book?
    @Binding var targetIndex: Int?
    
    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            draggedBook = nil
            targetIndex = nil
        }
        return true
    }
    
    func dropExited(info: DropInfo) {
        targetIndex = nil
    }
}

// MARK: - Optimized Grid Item
struct OptimizedGridItem: View {
    let book: Book
    let viewModel: LibraryViewModel
    let highlightedBookId: UUID?
    let onChangeCover: (Book) -> Void
    var isDraggable: Bool = false
    var isBeingDragged: Bool = false
    
    @State private var isPressed = false
    @State private var imageLoaded = false
    @State private var isHoldingForReorder = false
    
    var body: some View {
        NavigationLink(destination: BookDetailView(book: book).environmentObject(viewModel)) {
            ZStack {
                // Always show BookCard - no skeleton loading
                BookCard(book: book)
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Highlight overlay
                if highlightedBookId == book.localId {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(Color.orange, lineWidth: 3)
                        .animation(DesignSystem.Animation.easeStandard, value: highlightedBookId)
                }
            }
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(DesignSystem.Animation.springStandard, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            isPressed = pressing
            if pressing {
                SensoryFeedback.light()
            }
        } perform: {}
        .simultaneousGesture(TapGesture().onEnded { _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        })
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            bookContextMenu
        }
    }
    
    @ViewBuilder
    private var bookContextMenu: some View {
        Button {
            SensoryFeedback.light()
            withAnimation {
                viewModel.toggleReadingStatus(for: book)
            }
        } label: {
            Label(
                book.readingStatus == .read ? "Mark as Want to Read" : "Mark as Read",
                systemImage: book.readingStatus == .read ? "checkmark.circle.fill" : "checkmark.circle"
            )
        }
        
        Divider()
        
        Button {
            SensoryFeedback.light()
            shareBook()
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        
        Divider()
        
        Button {
            SensoryFeedback.light()
            onChangeCover(book)
        } label: {
            Label("Change Cover", systemImage: "photo")
        }
        
        Divider()
        
        Button(role: .destructive) {
            SensoryFeedback.light()
            withAnimation {
                viewModel.deleteBook(book)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func shareBook() {
        let text = "Check out \"\(book.title)\" by \(book.author)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Optimized Book Card Skeleton
struct OptimizedBookCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover placeholder
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 240)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            DesignSystem.Colors.textQuaternary,
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 80)
                    .rotationEffect(.degrees(25))
                    .offset(x: isAnimating ? 200 : -200)
                )
                .clipped()
            
            // Title placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 16)
            
            // Author placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 14)
                .frame(maxWidth: 120)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
