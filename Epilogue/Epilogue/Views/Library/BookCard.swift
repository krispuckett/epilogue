import SwiftUI

struct BookCard: View {
    let book: Book
    @State private var showingProgress = false
    @State private var longPressLocation: CGPoint = .zero
    @EnvironmentObject var viewModel: LibraryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Book cover
            BookCoverView(coverURL: book.coverImageURL)
                .frame(width: 170, height: 255)
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
            
            // Title and author only (no progress)
            VStack(alignment: .leading, spacing: 0) {
                Text(book.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(minHeight: 40)
                
                Text(book.author)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            showingProgress = true
            HapticManager.shared.mediumTap()
        }
        .popover(isPresented: $showingProgress) {
            ProgressPopover(book: book, viewModel: viewModel)
                .presentationCompactAdaptation(.popover)
                .preferredColorScheme(.dark)
        }
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
        self.accentColor = accentColor ?? Color(red: 1.0, green: 0.55, blue: 0.26)
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
                        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
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
        .padding(24)
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
        
        HapticManager.shared.lightTap()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isUpdating = false
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let accentColor: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 10)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0.11, green: 0.105, blue: 0.102)
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