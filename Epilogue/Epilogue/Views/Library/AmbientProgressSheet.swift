import SwiftUI

struct AmbientProgressSheet: View {
    let book: Book
    @Binding var isPresented: Bool
    @EnvironmentObject var viewModel: LibraryViewModel
    var colorPalette: ColorPalette? = nil
    
    @State private var currentPage: Int
    @State private var sliderValue: Double
    @State private var textFieldPage: String
    @State private var isUpdating = false
    @State private var showingPercentButtons = true
    @FocusState private var isTextFieldFocused: Bool
    
    private let amberColor = Color(red: 1.0, green: 0.55, blue: 0.26)
    
    private var primaryColor: Color {
        if let palette = colorPalette {
            return palette.primary
        }
        return amberColor
    }
    
    init(book: Book, isPresented: Binding<Bool>, colorPalette: ColorPalette? = nil) {
        self.book = book
        self._isPresented = isPresented
        self.colorPalette = colorPalette
        let page = book.currentPage
        self._currentPage = State(initialValue: page)
        self._sliderValue = State(initialValue: Double(page))
        self._textFieldPage = State(initialValue: String(page))
    }
    
    private var progress: Double {
        guard let pageCount = book.pageCount, pageCount > 0 else { return 0 }
        return Double(currentPage) / Double(pageCount)
    }
    
    private var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.95),
                        primaryColor.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Book info header
                        bookInfoHeader
                        
                        // Interactive Timeline - Centerpiece
                        VStack(spacing: 20) {
                            Text("Reading Timeline")
                                .font(.system(size: 20, weight: .semibold, design: .serif))
                                .foregroundStyle(.white)
                            
                            AmbientReadingProgressView(
                                book: Book.mockBook(currentPage: currentPage, totalPages: book.pageCount ?? 1),
                                width: UIScreen.main.bounds.width - 40,
                                showDetailed: true,
                                isInteractive: true,
                                onProgressChange: { newProgress in
                                    handleProgressChange(newProgress)
                                }
                            )
                            .environmentObject(viewModel)
                            .padding(.horizontal, -20) // Expand to edges
                        }
                        
                        // Fine-grained controls
                        VStack(spacing: 24) {
                            // Smooth slider
                            progressSlider
                            
                            // Page input with increment/decrement
                            pageInputControls
                            
                            // Quick percentage buttons
                            if showingPercentButtons && !isTextFieldFocused {
                                percentageButtons
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Stats and insights
                        readingStats
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveProgress()
                        isPresented = false
                    }
                    .foregroundStyle(primaryColor)
                    .fontWeight(.medium)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: progressPercentage)
    }
    
    // MARK: - Subviews
    
    private var bookInfoHeader: some View {
        HStack(spacing: 16) {
            // Mini book cover
            if let coverURL = book.coverImageURL {
                SharedBookCoverView(
                    coverURL: coverURL,
                    width: 60,
                    height: 90
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                
                if let pageCount = book.pageCount {
                    HStack(spacing: 8) {
                        Label("\(progressPercentage)%", systemImage: "chart.pie.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(primaryColor)
                        
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text("\(currentPage) of \(pageCount)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private var progressSlider: some View {
        VStack(spacing: 12) {
            Text("Drag to Adjust")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)
            
            Slider(
                value: $sliderValue,
                in: 0...Double(book.pageCount ?? 1),
                step: 1
            )
            .tint(primaryColor)
            .onChange(of: sliderValue) { _, newValue in
                currentPage = Int(newValue)
                textFieldPage = String(currentPage)
                HapticManager.shared.selectionChanged()
            }
            
            // Tick marks
            HStack {
                ForEach([0, 25, 50, 75, 100], id: \.self) { percentage in
                    Text("\(percentage)%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(primaryColor.opacity(0.2), lineWidth: 0.5)
                }
        )
    }
    
    private var pageInputControls: some View {
        HStack(spacing: 20) {
            // Decrement button
            Button {
                decrementPage()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(primaryColor)
                    .opacity(currentPage > 0 ? 1 : 0.3)
            }
            .disabled(currentPage <= 0)
            
            // Page input field
            VStack(spacing: 8) {
                Text("Page Number")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                
                TextField("Page", text: $textFieldPage)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 120)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        isTextFieldFocused ? primaryColor : Color.white.opacity(0.2),
                                        lineWidth: 1
                                    )
                            }
                    )
                    .focused($isTextFieldFocused)
                    .onChange(of: textFieldPage) { _, newValue in
                        if let page = Int(newValue), page >= 0, page <= (book.pageCount ?? 0) {
                            currentPage = page
                            sliderValue = Double(page)
                        }
                    }
                    .onSubmit {
                        isTextFieldFocused = false
                    }
            }
            
            // Increment button
            Button {
                incrementPage()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(primaryColor)
                    .opacity(currentPage < (book.pageCount ?? 0) ? 1 : 0.3)
            }
            .disabled(currentPage >= (book.pageCount ?? 0))
        }
    }
    
    private var percentageButtons: some View {
        VStack(spacing: 12) {
            Text("Quick Jump")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)
            
            HStack(spacing: 12) {
                ForEach([0, 25, 50, 75, 100], id: \.self) { percentage in
                    Button {
                        jumpToPercentage(percentage)
                    } label: {
                        Text("\(percentage)%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(progressPercentage == percentage ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(progressPercentage == percentage ? primaryColor : Color.white.opacity(0.1))
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        progressPercentage == percentage ? primaryColor : Color.white.opacity(0.2),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .scaleEffect(progressPercentage == percentage ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progressPercentage == percentage)
                }
            }
        }
    }
    
    private var readingStats: some View {
        HStack(spacing: 20) {
            ProgressStatCard(
                icon: "book.pages",
                title: "Pages Read",
                value: "\(currentPage)",
                color: primaryColor
            )
            
            ProgressStatCard(
                icon: "timer",
                title: "Time Left",
                value: estimatedTimeRemaining,
                color: .blue
            )
            
            ProgressStatCard(
                icon: "calendar",
                title: "Pace",
                value: readingPace,
                color: .green
            )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Methods
    
    private var estimatedTimeRemaining: String {
        guard let pageCount = book.pageCount else { return "—" }
        let pagesRemaining = pageCount - currentPage
        let pagesPerMinute = 1.5
        let minutes = Double(pagesRemaining) / pagesPerMinute
        let hours = Int(minutes / 60)
        let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
    
    private var readingPace: String {
        // Calculate based on book's dateAdded
        let daysReading = 7 // Placeholder
        let pagesPerDay = currentPage / max(1, daysReading)
        return "\(pagesPerDay)/day"
    }
    
    private func handleProgressChange(_ newProgress: Double) {
        guard let pageCount = book.pageCount else { return }
        let newPage = Int(newProgress * Double(pageCount))
        currentPage = newPage
        sliderValue = Double(newPage)
        textFieldPage = String(newPage)
    }
    
    private func incrementPage() {
        guard let pageCount = book.pageCount, currentPage < pageCount else { return }
        currentPage += 1
        sliderValue = Double(currentPage)
        textFieldPage = String(currentPage)
        HapticManager.shared.pageTurn()
    }
    
    private func decrementPage() {
        guard currentPage > 0 else { return }
        currentPage -= 1
        sliderValue = Double(currentPage)
        textFieldPage = String(currentPage)
        HapticManager.shared.pageTurn()
    }
    
    private func jumpToPercentage(_ percentage: Int) {
        guard let pageCount = book.pageCount else { return }
        let targetPage = Int(Double(pageCount) * Double(percentage) / 100.0)
        currentPage = targetPage
        sliderValue = Double(targetPage)
        textFieldPage = String(targetPage)
        HapticManager.shared.mediumTap()
    }
    
    private func saveProgress() {
        guard !isUpdating else { return }
        isUpdating = true
        
        // Update via viewModel
        viewModel.updateBookProgress(book, currentPage: currentPage)
        HapticManager.shared.success()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isUpdating = false
        }
    }
}

// MARK: - Supporting Views

struct ProgressStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
                }
        )
    }
}

// MARK: - Preview

#Preview {
    AmbientProgressSheet(
        book: Book.mockBook(currentPage: 127, totalPages: 354),
        isPresented: .constant(true),
        colorPalette: nil
    )
    .environmentObject(LibraryViewModel())
}