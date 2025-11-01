import SwiftUI

struct BookCompletionSheet: View {
    @Binding var book: Book
    @Binding var isPresented: Bool
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    // State for the form
    @State private var rating: Double = 0.0  // Supports half-star ratings (0.5 increments)
    @State private var reviewText: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var isFavorite: Bool = false
    @State private var animateStars = false
    @State private var isDragging = false
    @State private var lastHapticRating: Double = 0.0
    @FocusState private var isReviewFocused: Bool
    
    // Available emotional tags - curated selection
    private let emotionalTags = [
        "#inspiring", "#thoughtful", "#challenging",
        "#comforting", "#unforgettable", "#entertaining"
    ]
    
    private var readingStats: (days: Int, pagesPerDay: Int) {
        let days = Calendar.current.dateComponents([.day], from: book.dateAdded, to: Date()).day ?? 1
        let pagesPerDay = (book.pageCount ?? 0) / max(1, days)
        return (days, pagesPerDay)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.surfaceBackground,
                        Color(red: 0.08, green: 0.075, blue: 0.072)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Book cover and title
                        headerSection
                        
                        // Rating section
                        ratingSection
                        
                        // Review text section
                        reviewSection
                        
                        // Reading stats
                        statsSection
                        
                        // Favorite toggle
                        favoriteSection
                        
                        // Emotional tags section (optional, at bottom)
                        tagsSection
                    }
                    .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("Complete Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        SensoryFeedback.light()
                        isPresented = false
                    }
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReview()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .onAppear {
            // Load existing data if editing
            if let existingRating = book.userRating {
                rating = existingRating
            }
            if let existingNotes = book.userNotes {
                reviewText = existingNotes
            }
            
            // Animate stars on appear
            withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                animateStars = true
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 120,
                height: 180
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            
            VStack(spacing: 8) {
                Text(book.title)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text("by \(book.author)")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }
    
    @ViewBuilder
    private var ratingSection: some View {
        VStack(spacing: 16) {
            Text("How would you rate this book?")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))

            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let starWidth: CGFloat = 44
                let spacing: CGFloat = 12
                let totalStarsWidth = (starWidth * 5) + (spacing * 4)
                let xOffset = (totalWidth - totalStarsWidth) / 2  // Center the stars

                ZStack(alignment: .leading) {
                    // Star icons - clean and precise
                    HStack(spacing: spacing) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: starIcon(for: star))
                                .font(.system(size: 36))
                                .foregroundStyle(starColor(for: star))
                                .frame(width: starWidth, height: starWidth)
                                .scaleEffect(starScale(for: star))
                                .animation(
                                    isDragging ? .none : .spring(response: 0.3, dampingFraction: 0.7),
                                    value: rating
                                )
                        }
                    }
                    .offset(x: xOffset)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                            }

                            let newRating = calculateRatingFromDrag(
                                xPosition: value.location.x,
                                containerWidth: totalWidth,
                                starWidth: starWidth,
                                spacing: spacing
                            )

                            if newRating != rating {
                                rating = newRating

                                // Refined haptic: only on half-star boundaries
                                if newRating != lastHapticRating {
                                    SensoryFeedback.selection()
                                    lastHapticRating = newRating
                                }
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                            SensoryFeedback.light()  // Final confirmation
                        }
                )
            }
            .frame(height: 44)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Star Visual Helpers

    private func starScale(for star: Int) -> CGFloat {
        let starValue = Double(star)

        // Initial appearance animation
        if !animateStars {
            return 0.8
        }

        // During drag: no scaling variance
        if isDragging {
            return 1.0
        }

        // At rest: subtle scale for filled stars
        if rating >= starValue - 0.5 {
            return 1.0
        } else {
            return 0.95
        }
    }

    // MARK: - Rating Calculation

    private func calculateRatingFromDrag(xPosition: CGFloat, containerWidth: CGFloat, starWidth: CGFloat, spacing: CGFloat) -> Double {
        let totalStarsWidth = (starWidth * 5) + (spacing * 4)
        let xOffset = (containerWidth - totalStarsWidth) / 2

        // Adjust position relative to first star
        let relativeX = xPosition - xOffset

        // Below minimum: no rating
        if relativeX <= 0 { return 0.0 }

        // Above maximum: 5 stars
        if relativeX >= totalStarsWidth { return 5.0 }

        // Calculate which star we're in
        for starIndex in 0..<5 {
            let starStart = CGFloat(starIndex) * (starWidth + spacing)
            let starEnd = starStart + starWidth

            // Check if we're within this star's bounds
            if relativeX >= starStart && relativeX < starEnd {
                let positionInStar = relativeX - starStart
                let halfWidth = starWidth / 2
                let baseRating = Double(starIndex + 1)

                // Left half = X.5, Right half = X.0
                if positionInStar < halfWidth {
                    return baseRating - 0.5
                } else {
                    return baseRating
                }
            }

            // If we're in the spacing after this star (before next star)
            if relativeX >= starEnd && starIndex < 4 {
                let nextStarStart = CGFloat(starIndex + 1) * (starWidth + spacing)
                if relativeX < nextStarStart {
                    // In the gap: use the full rating of the star we just left
                    return Double(starIndex + 1)
                }
            }
        }

        return 5.0
    }

    // MARK: - Star Helper Methods

    private func starIcon(for star: Int) -> String {
        let starValue = Double(star)
        if rating >= starValue {
            return "star.fill"
        } else if rating >= starValue - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    private func starColor(for star: Int) -> Color {
        let starValue = Double(star)
        if rating >= starValue - 0.5 {
            return DesignSystem.Colors.primaryAccent
        } else {
            return DesignSystem.Colors.textQuaternary
        }
    }
    
    @ViewBuilder
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                
                Text("Review")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                
                Spacer()
                
                if !reviewText.isEmpty {
                    Text("\(reviewText.count) characters")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            
            TextEditor(text: $reviewText)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 120)
                .padding(12)
                .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .focused($isReviewFocused)
                .placeholder(when: reviewText.isEmpty) {
                    Text("What did you think about this book?")
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(DesignSystem.Colors.textQuaternary)
                        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
        }
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.7))
                
                Text("Tags (optional)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                if !selectedTags.isEmpty {
                    Text("\(selectedTags.count) selected")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(emotionalTags, id: \.self) { tag in
                        TagPill(
                            text: tag,
                            isSelected: selectedTags.contains(tag),
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                    SensoryFeedback.light()
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
    
    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                
                Text("Reading Statistics")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            
            HStack(spacing: 32) {
                VStack(alignment: .leading) {
                    Text("\(readingStats.days)")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("days to complete")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                VStack(alignment: .leading) {
                    Text("\(readingStats.pagesPerDay)")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("pages per day")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.inlinePadding)
            .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
    
    @ViewBuilder
    private var favoriteSection: some View {
        HStack {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 20))
                .foregroundStyle(
                    isFavorite ? 
                    DesignSystem.Colors.primaryAccent : 
                    DesignSystem.Colors.textTertiary
                )
            
            Text("Mark as Favorite")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
            
            Toggle("", isOn: $isFavorite)
                .labelsHidden()
                .tint(DesignSystem.Colors.primaryAccent)
                .onChange(of: isFavorite) { _, _ in
                    SensoryFeedback.light()
                }
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
    
    // MARK: - Actions
    
    private func saveReview() {
        // Create updated book
        var updatedBook = book
        updatedBook.userRating = rating > 0 ? rating : nil
        updatedBook.userNotes = reviewText.isEmpty ? nil : reviewText
        
        // Mark as read if not already
        if updatedBook.readingStatus != .read {
            updatedBook.readingStatus = .read
        }
        
        // Update via binding (this triggers the setter in BookDetailView)
        book = updatedBook
        
        // Also update in library to persist
        libraryViewModel.updateBook(updatedBook)
        
        // Haptic feedback
        SensoryFeedback.success()
        
        // Dismiss
        isPresented = false
    }
}

// MARK: - Supporting Views

struct TagPill: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    isSelected ? 
                    .white : 
                    DesignSystem.Colors.textSecondary
                )
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.3))
                            .overlay {
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                                    .strokeBorder(
                                        DesignSystem.Colors.primaryAccent,
                                        lineWidth: 1
                                    )
                            }
                    } else {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .fill(.white.opacity(0.10))
                            .overlay {
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                            }
                    }
                }
        }
    }
}

// MARK: - View Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}