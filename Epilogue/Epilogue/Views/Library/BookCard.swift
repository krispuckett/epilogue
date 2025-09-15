import SwiftUI

struct BookCard: View {
    let book: Book
    @State private var isPressed = false
    @EnvironmentObject var viewModel: LibraryViewModel
    @Environment(\.sizeCategory) var sizeCategory
    
    // Normalize author spacing to be consistent (J.R.R. instead of J. R. R.)
    private func normalizeAuthorSpacing(_ author: String) -> String {
        // Replace multiple spaces with single space first
        let singleSpaced = author.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // Remove spaces between single initials (e.g., "J. R. R." becomes "J.R.R.")
        let normalized = singleSpaced.replacingOccurrences(of: "\\b([A-Z])\\.\\s+(?=[A-Z]\\.)", with: "$1.", options: .regularExpression)
        return normalized
    }
    
    private var accessibilityLabel: String {
        let pages = book.pageCount ?? 0
        let currentPage = book.currentPage
        let progress = pages > 0 ? Int((Double(currentPage) / Double(pages)) * 100) : 0
        
        return "\(book.title) by \(book.author). Reading progress: \(progress)% complete, page \(currentPage) of \(pages)."
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Book cover - using thumbnail for grid view with library flag
            Group {
                // DEBUG: Log the book details
                let _ = print("🎴 BookCard rendering book:")
                let _ = print("   Title: \(book.title)")
                let _ = print("   Author: \(book.author)")
                let _ = print("   ID: \(book.id)")
                let _ = print("   LocalID: \(book.localId)")
                let _ = print("   Cover URL: \(book.coverImageURL ?? "nil")")
                let _ = print("   Cover URL is nil? \(book.coverImageURL == nil)")
                let _ = print("   Cover URL is empty? \(book.coverImageURL?.isEmpty ?? true)")
                
                SharedBookCoverView(
                    coverURL: book.coverImageURL,
                    width: 170,
                    height: 255,
                    loadFullImage: false,
                    isLibraryView: true
                )
                .accessibilityHidden(true) // Hide decorative image from VoiceOver
            }
            
            // Title and author
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: sizeCategory.isAccessibilitySize ? 20 : 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .lineLimit(sizeCategory.isAccessibilitySize ? 3 : 2)
                    .truncationMode(.tail)
                    .frame(minHeight: sizeCategory.isAccessibilitySize ? 60 : 40)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(normalizeAuthorSpacing(book.author))
                    .font(.system(size: sizeCategory.isAccessibilitySize ? 16 : 13, weight: .regular, design: .monospaced))
                    .kerning(0.8)  // Reduced kerning since we're normalizing spaces
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                    .lineLimit(sizeCategory.isAccessibilitySize ? 2 : 1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Progress indicator removed per user request
        }
        .smoothScale(0.96, isActive: isPressed)
        // Long press removed per user request - no more progress popup
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}

struct ProgressPopover: View {
    let book: Book
    let viewModel: LibraryViewModel
    let accentColor: Color
    @State private var currentPage: Int
    @State private var sliderValue: Double
    @State private var isUpdating = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    init(book: Book, viewModel: LibraryViewModel, accentColor: Color? = nil) {
        self.book = book
        self.viewModel = viewModel
        self.accentColor = accentColor ?? DesignSystem.Colors.primaryAccent
        let page = book.currentPage
        _currentPage = State(initialValue: page)
        _sliderValue = State(initialValue: Double(page))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Reading Progress")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            // Progress visualization
            CircularProgressView(
                progress: Double(currentPage) / Double(book.pageCount ?? 1),
                accentColor: accentColor
            )
            .frame(width: 100, height: 100)
            
            // Interactive slider
            VStack(spacing: 8) {
                Slider(
                    value: $sliderValue,
                    in: 0...Double(book.pageCount ?? 1),
                    step: 1,
                    onEditingChanged: { editing in
                        if !editing {
                            currentPage = Int(sliderValue)
                            HapticManager.shared.pageTurn()
                            updateProgress()
                        }
                    }
                )
                .tint(accentColor)
                .onChange(of: sliderValue) { _, newValue in
                    // Update currentPage on next run loop to avoid state modification during view update
                    Task { @MainActor in
                        currentPage = Int(newValue)
                    }
                }
                
                // Percentage labels
                HStack {
                    Text("0%")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("25%")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("50%")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("75%")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("100%")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            // Page input
            VStack(spacing: 12) {
                Text("Page \(currentPage) of \(book.pageCount ?? 0)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                
                HStack(spacing: 16) {
                    Button {
                        if currentPage > 0 {
                            currentPage -= 1
                            sliderValue = Double(currentPage)
                            HapticManager.shared.pageTurn()
                            updateProgress()
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(accentColor)
                    }
                    
                    TextField("Page", value: $currentPage, format: .number)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                        .padding(.vertical, 10)
                        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            sliderValue = Double(currentPage)
                            updateProgress()
                        }
                        .onTapGesture {
                            isTextFieldFocused = true
                        }
                    
                    Button {
                        if currentPage < (book.pageCount ?? 0) {
                            currentPage += 1
                            sliderValue = Double(currentPage)
                            HapticManager.shared.pageTurn()
                            updateProgress()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(accentColor)
                    }
                }
            }
            
            // Quick progress buttons - hide when text field is focused
            if !isTextFieldFocused {
                HStack(spacing: 10) {
                    ForEach([25, 50, 75, 100], id: \.self) { percentage in
                        Button {
                            currentPage = Int(Double(book.pageCount ?? 0) * Double(percentage) / 100.0)
                            sliderValue = Double(currentPage)
                            HapticManager.shared.pageTurn()
                            updateProgress()
                        } label: {
                            Text("\(percentage)%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .glassEffect(in: Capsule())
                        }
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .frame(width: 320)
        .presentationBackground(.ultraThinMaterial)
        .onTapGesture {
            isTextFieldFocused = false
        }
    }
    
    private func updateProgress() {
        guard !isUpdating else { return }
        isUpdating = true
        
        // Update book progress
        viewModel.updateBookProgress(book, currentPage: currentPage)
        
        SensoryFeedback.light()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isUpdating = false
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let accentColor: Color
    var isIndeterminate: Bool = false
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            if isIndeterminate {
                // Indeterminate spinner
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            } else {
                // Determinate progress
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    // Only animate when progress actually changes, not on load
                    .animation(progress > 0 ? .spring(response: 0.5) : nil, value: progress)
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    ZStack {
        DesignSystem.Colors.surfaceBackground
            .ignoresSafeArea()
        
        BookCard(
            book: Book(
                id: "1",
                title: "The Great Gatsby",
                author: "F. Scott Fitzgerald",
                publishedYear: "1925",
                coverImageURL: nil,
                pageCount: 180,
                localId: UUID()
            )
        )
        .environmentObject(LibraryViewModel())
        .padding()
    }
}