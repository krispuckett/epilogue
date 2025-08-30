import SwiftUI

// MARK: - Skeleton View
struct SkeletonView: View {
    @State private var isAnimating = false
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay {
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.5)
                        .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                        .animation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
            }
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Book Card Skeleton
struct BookCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover image skeleton
            SkeletonView(cornerRadius: DesignSystem.CornerRadius.small)
                .aspectRatio(2/3, contentMode: .fit)
            
            // Title skeleton
            SkeletonView(cornerRadius: 4)
                .frame(height: 16)
            
            // Author skeleton
            SkeletonView(cornerRadius: 4)
                .frame(height: 12)
                .padding(.trailing, 40)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

// MARK: - List Row Skeleton
struct ListRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Cover skeleton
            SkeletonView(cornerRadius: DesignSystem.CornerRadius.small)
                .frame(width: 60, height: 80)
            
            VStack(alignment: .leading, spacing: 8) {
                // Title
                SkeletonView(cornerRadius: 4)
                    .frame(height: 18)
                
                // Author
                SkeletonView(cornerRadius: 4)
                    .frame(height: 14)
                    .padding(.trailing, 60)
                
                Spacer()
                
                // Progress bar
                SkeletonView(cornerRadius: 2)
                    .frame(width: 80, height: 4)
            }
            
            Spacer()
        }
        .padding(12)
        .frame(height: 104)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color.black.opacity(0.2))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
        )
    }
}

// MARK: - Note Card Skeleton
struct NoteCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                SkeletonView(cornerRadius: 4)
                    .frame(width: 60, height: 14)
                
                Spacer()
                
                SkeletonView(cornerRadius: 4)
                    .frame(width: 40, height: 12)
            }
            
            // Content lines
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(cornerRadius: 4)
                    .frame(height: 14)
                
                SkeletonView(cornerRadius: 4)
                    .frame(height: 14)
                    .padding(.trailing, 30)
                
                SkeletonView(cornerRadius: 4)
                    .frame(height: 14)
                    .padding(.trailing, 80)
            }
            
            // Book info
            SkeletonView(cornerRadius: 4)
                .frame(width: 120, height: 12)
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Skeleton Grid
struct SkeletonGrid: View {
    let columns: Int
    let rows: Int
    let spacing: CGFloat
    
    init(columns: Int = 2, rows: Int = 3, spacing: CGFloat = 16) {
        self.columns = columns
        self.rows = rows
        self.spacing = spacing
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(0..<(columns * rows), id: \.self) { _ in
                BookCardSkeleton()
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Skeleton List
struct SkeletonList: View {
    let count: Int
    
    init(count: Int = 5) {
        self.count = count
    }
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<count, id: \.self) { _ in
                ListRowSkeleton()
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - View Extension
extension View {
    @ViewBuilder
    func skeleton(
        isLoading: Bool,
        cornerRadius: CGFloat = 8,
        transition: AnyTransition = .opacity.combined(with: .scale(scale: 0.98))
    ) -> some View {
        if isLoading {
            SkeletonView(cornerRadius: cornerRadius)
                .transition(transition)
        } else {
            self
                .transition(transition)
        }
    }
}