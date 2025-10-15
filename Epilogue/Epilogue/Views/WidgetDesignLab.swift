import SwiftUI
import SwiftData

/// TEMPORARY: Design lab for prototyping widgets before implementation
/// DELETE THIS FILE once we finalize widget designs
struct WidgetDesignLab: View {
    @Environment(\.modelContext) private var modelContext
    @State private var demoBook: DemoBookData = .theOdyssey
    @State private var demoQuote: CapturedQuote?
    @State private var sessionMinutes = 23
    @State private var readingGoalMinutes = 45
    @State private var streakDays = 18
    @State private var bookGradientColors: [Color] = []

    var progress: Double {
        guard demoBook.totalPages > 0 else { return 0 }
        return Double(demoBook.currentPage) / Double(demoBook.totalPages)
    }

    var sessionProgress: Double {
        Double(sessionMinutes) / Double(readingGoalMinutes)
    }

    // MARK: - Demo Book Data
    struct DemoBookData {
        let title: String
        let author: String
        let coverURL: String
        let currentPage: Int
        let totalPages: Int

        static let theOdyssey = DemoBookData(
            title: "The Odyssey",
            author: "Homer",
            coverURL: "https://books.google.com/books/content?id=gawjEQAAQBAJ&printsec=frontcover&img=1&zoom=1&source=gbs_api",
            currentPage: 142,
            totalPages: 400
        )

        static let theHobbit = DemoBookData(
            title: "The Hobbit",
            author: "J.R.R. Tolkien",
            coverURL: "https://books.google.com/books/content?id=pD6arNyKyi8C&printsec=frontcover&img=1&zoom=1&edge=curl",
            currentPage: 89,
            totalPages: 366
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    // Section: Current Reading Widgets
                    designSection(title: "Current Reading Widget", subtitle: "Clean, minimal, polished") {
                        VStack(spacing: 20) {
                            widgetPreview(size: "Small (2x2)", width: 170, height: 170) {
                                currentReadingSmallWidget
                            }

                            widgetPreview(size: "Medium (4x2)", width: 360, height: 170) {
                                currentReadingMediumWidget
                            }

                            widgetPreview(size: "Large (4x4)", width: 360, height: 360) {
                                currentReadingLargeWidget
                            }
                        }
                    }

                    // Section: Reading Session Timer Widget
                    designSection(title: "Reading Session Timer", subtitle: "Active session tracking") {
                        VStack(spacing: 20) {
                            widgetPreview(size: "Medium (4x2)", width: 360, height: 170) {
                                readingSessionMediumWidget
                            }

                            widgetPreview(size: "Large (4x4)", width: 360, height: 360) {
                                readingSessionLargeWidget
                            }
                        }
                    }

                    // Section: Ambient Mode Widget
                    designSection(title: "Ambient Mode Widget", subtitle: "Quick AI access") {
                        VStack(spacing: 20) {
                            widgetPreview(size: "Small (2x2)", width: 170, height: 170) {
                                ambientModeSmallWidget
                            }

                            widgetPreview(size: "Medium (4x2)", width: 360, height: 170) {
                                ambientModeMediumWidget
                            }
                        }
                    }

                    // Section: Quote Widgets
                    designSection(title: "Quote of the Day Widget", subtitle: "Daily inspiration") {
                        VStack(spacing: 20) {
                            widgetPreview(size: "Large (4x4)", width: 360, height: 360) {
                                quoteLargeWidget
                            }
                        }
                    }

                    // Section: Streak Widget
                    designSection(title: "Reading Streak", subtitle: "Habit tracking") {
                        VStack(spacing: 20) {
                            widgetPreview(size: "Small (2x2)", width: 170, height: 170) {
                                streakSmallWidget
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }
            .background(Color.black)
            .navigationTitle("Widget Design Lab")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Dismiss
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .task {
            await loadDemoData()
        }
    }

    // MARK: - Load Demo Data
    @MainActor
    private func loadDemoData() async {
        // Load a real quote from the database if available
        let quotesDescriptor = FetchDescriptor<CapturedQuote>(
            sortBy: [SortDescriptor<CapturedQuote>(\.timestamp, order: .reverse)]
        )
        if let quote = try? modelContext.fetch(quotesDescriptor).first {
            demoQuote = quote
            #if DEBUG
            print("📱 WidgetDesignLab: Using real quote: \(quote.text?.prefix(50) ?? "")")
            #endif
        } else {
            #if DEBUG
            print("📱 WidgetDesignLab: No quotes in database, using hardcoded demo")
            #endif
        }

        // Extract gradient colors from demo book cover
        if let image = await SharedBookCoverManager.shared.loadFullImage(from: demoBook.coverURL) {
            do {
                let extractor = OKLABColorExtractor()
                let palette = try await extractor.extractPalette(from: image, imageSource: "demo-widget")
                bookGradientColors = [palette.primary, palette.secondary, palette.accent, palette.background]
                #if DEBUG
                print("🎨 WidgetDesignLab: Extracted gradient colors from \(demoBook.title)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ WidgetDesignLab: Failed to extract colors, using defaults")
                #endif
                bookGradientColors = defaultGradientColors
            }
        } else {
            #if DEBUG
            print("⚠️ WidgetDesignLab: Failed to load cover image, using defaults")
            #endif
            bookGradientColors = defaultGradientColors
        }
    }

    private var defaultGradientColors: [Color] {
        [
            Color(red: 1.0, green: 0.549, blue: 0.259),
            Color(red: 0.98, green: 0.4, blue: 0.2),
            Color(red: 0.9, green: 0.35, blue: 0.18),
            Color(red: 0.85, green: 0.3, blue: 0.15)
        ]
    }

    // MARK: - Design Section Helper
    private func designSection(title: String, subtitle: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            content()
        }
    }

    // MARK: - Widget Preview Helper
    private func widgetPreview(size: String, width: CGFloat, height: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(size)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            content()
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 15)
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════
    // MARK: - CURRENT READING WIDGETS (ULTRA POLISHED)
    // MARK: - ═══════════════════════════════════════════════════════════

    private var currentReadingSmallWidget: some View {
        ZStack {
            Color.black

            // Atmospheric gradient
            realAtmosphericGradient

            VStack(spacing: 8) {
                // BOOK COVER - Smaller
                SharedBookCoverView(
                    coverURL: demoBook.coverURL,
                    width: 55,
                    height: 82,
                    loadFullImage: false,
                    isLibraryView: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)

                Spacer()

                // Circular progress ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 3)
                        .frame(width: 54, height: 54)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: bookGradientColors.isEmpty ? [
                                    DesignSystem.Colors.primaryAccent,
                                    DesignSystem.Colors.primaryAccent.opacity(0.7)
                                ] : [
                                    bookGradientColors[0],
                                    bookGradientColors[1]
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(-90))

                    // Percentage - MONOSPACED
                    Text("\(Int(progress * 100))")
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            .padding(.vertical, 16)
        }
    }

    private var currentReadingMediumWidget: some View {
        ZStack {
            Color.black

            // Atmospheric gradient
            realAtmosphericGradient

            HStack(spacing: 16) {
                // BOOK COVER - Left side
                SharedBookCoverView(
                    coverURL: demoBook.coverURL,
                    width: 75,
                    height: 112,
                    loadFullImage: false,
                    isLibraryView: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 4)

                // Content - Right side, vertically centered with cover
                VStack(alignment: .leading, spacing: 8) {
                    // Book title - Georgia
                    Text(demoBook.title)
                        .font(.custom("Georgia", size: 21))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                        .frame(height: 4)

                    // Progress slider with glass handle
                    progressSliderView

                    Spacer()
                        .frame(height: 2)

                    // Page count - MONOSPACED
                    HStack(spacing: 4) {
                        Text("\(demoBook.currentPage)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("/")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))

                        Text("\(demoBook.totalPages)")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))

                        Text("pages")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.leading, 2)
                    }
                }
                .frame(height: 112) // Exactly match cover height for perfect alignment
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
    }

    private var currentReadingLargeWidget: some View {
        ZStack {
            Color.black

            // Atmospheric gradient
            realAtmosphericGradient

            VStack(spacing: 0) {
                // Top padding
                Spacer()
                    .frame(height: 32)

                // BOOK COVER - Top center with padding
                SharedBookCoverView(
                    coverURL: demoBook.coverURL,
                    width: 70,
                    height: 105,
                    loadFullImage: false,
                    isLibraryView: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 4)

                Spacer()
                    .frame(height: 12)

                // Title and author - Smaller
                VStack(spacing: 4) {
                    Text(demoBook.title)
                        .font(.custom("Georgia", size: 17))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(demoBook.author)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .multilineTextAlignment(.center)

                Spacer()
                    .frame(height: 20)

                // Smaller progress ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 3)
                        .frame(width: 100, height: 100)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: bookGradientColors.isEmpty ? [
                                    DesignSystem.Colors.primaryAccent.opacity(0.8),
                                    DesignSystem.Colors.primaryAccent
                                ] : [
                                    bookGradientColors[1],
                                    bookGradientColors[0]
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .shadow(
                            color: (bookGradientColors.first ?? DesignSystem.Colors.primaryAccent).opacity(0.5),
                            radius: 6,
                            x: 0,
                            y: 0
                        )

                    // Percentage - MONOSPACED
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                Spacer()
                    .frame(height: 24)

                // Stats - MONOSPACED, same font size, baseline aligned labels
                HStack(alignment: .bottom, spacing: 40) {
                    VStack(spacing: 3) {
                        Text("\(demoBook.totalPages - demoBook.currentPage)")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("pages left")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    VStack(spacing: 3) {
                        Text("14h 46m")
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .foregroundStyle(bookGradientColors.first ?? DesignSystem.Colors.primaryAccent)

                        Text("remaining")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }

                // Bottom padding
                Spacer()
                    .frame(height: 28)
            }
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════
    // MARK: - READING SESSION TIMER WIDGET
    // MARK: - ═══════════════════════════════════════════════════════════

    private var readingSessionMediumWidget: some View {
        ZStack {
            Color.black

            // Subtle atmospheric gradient
            realAtmosphericGradient

            HStack(spacing: 14) {
                // BOOK COVER
                SharedBookCoverView(
                    coverURL: demoBook.coverURL,
                    width: 90,
                    height: 135,
                    loadFullImage: false,
                    isLibraryView: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 0) {
                    // Live indicator
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)

                        Text("Reading")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.bottom, 6)

                    Spacer()

                    // Timer - HUGE MONOSPACED with colon
                    HStack(spacing: 0) {
                        Text("\(sessionMinutes)")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                        Text(":")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                        Text("14")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.white)

                    Spacer()

                    // Goal progress slider
                    goalProgressSlider
                        .padding(.bottom, 4)
                }
                .padding(.trailing, 4)
            }
            .padding(14)
        }
    }

    private var readingSessionLargeWidget: some View {
        ZStack {
            Color.black

            // Atmospheric gradient
            realAtmosphericGradient

            VStack(spacing: 0) {
                // Top spacing
                Spacer()
                    .frame(height: 24)

                // Centered cover
                SharedBookCoverView(
                    coverURL: demoBook.coverURL,
                    width: 70,
                    height: 105,
                    loadFullImage: false,
                    isLibraryView: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 4)

                Spacer()
                    .frame(height: 10)

                // Title centered below cover
                Text(demoBook.title)
                    .font(.custom("Georgia", size: 17))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)

                Spacer()
                    .frame(height: 24)

                // Reading status indicator above timer
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)

                    Text("Reading")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()
                    .frame(height: 12)

                // TIMER - MONOSPACED, centered
                HStack(spacing: 0) {
                    Text("\(sessionMinutes)")
                        .font(.system(size: 72, weight: .bold, design: .monospaced))
                    Text(":")
                        .font(.system(size: 72, weight: .bold, design: .monospaced))
                    Text("14")
                        .font(.system(size: 72, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white)

                Spacer()
                    .frame(height: 28)

                // Goal progress
                VStack(spacing: 12) {
                    goalProgressSlider

                    HStack {
                        Text("\(sessionMinutes) / \(readingGoalMinutes) min")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)

                        Spacer()

                        Text("Daily goal")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .padding(.horizontal, 20)

                // Bottom spacing
                Spacer()
                    .frame(height: 20)
            }
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════
    // MARK: - AMBIENT MODE WIDGET
    // MARK: - ═══════════════════════════════════════════════════════════

    private var ambientModeSmallWidget: some View {
        ZStack {
            Color.black

            // Ambient gradient (amber/orange tones)
            ambientAtmosphericGradient

            VStack(spacing: 12) {
                // REAL Metal shader orb - larger
                AmbientOrbButton(size: 80) {}
                    .disabled(true)

                Text("Ask")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Epilogue")
                    .font(.custom("Georgia", size: 14))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var ambientModeMediumWidget: some View {
        ZStack {
            Color.black

            // Ambient gradient (amber/orange tones)
            ambientAtmosphericGradient

            HStack(spacing: 20) {
                // REAL Metal shader orb - larger
                AmbientOrbButton(size: 90) {}
                    .disabled(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Ask Epilogue")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Tap to open Ambient Mode")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private var ambientAtmosphericGradient: some View {
        let amberColors = defaultGradientColors

        return LinearGradient(
            stops: [
                .init(color: amberColors[0].opacity(1.0), location: 0.0),
                .init(color: amberColors[1].opacity(0.8), location: 0.15),
                .init(color: amberColors[2].opacity(0.5), location: 0.3),
                .init(color: amberColors[3].opacity(0.3), location: 0.45),
                .init(color: Color.clear, location: 0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 40)
    }

    // MARK: - ═══════════════════════════════════════════════════════════
    // MARK: - QUOTE WIDGET (LARGE ONLY)
    // MARK: - ═══════════════════════════════════════════════════════════

    private var quoteLargeWidget: some View {
        ZStack {
            Color.black

            // Amber atmospheric gradient
            ambientAtmosphericGradient

            VStack(alignment: .leading, spacing: 0) {
                Text("\u{201C}")
                    .font(.custom("Georgia", size: 85))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.3))
                    .offset(x: -10, y: 22)
                    .frame(height: 0)
                    .padding(.top, 36)

                HStack(alignment: .top, spacing: 0) {
                    Text("A")
                        .font(.custom("Georgia", size: 59))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        .padding(.trailing, 4)
                        .offset(y: -8)

                    Text("ll we have to decide is what to do with the time given to us.")
                        .font(.custom("Georgia", size: 25))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        .lineSpacing(10)
                        .padding(.top, 6)
                }
                .padding(.top, 20)

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    LinearGradient(gradient: Gradient(stops: [
                        .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 0),
                        .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(1.0), location: 0.5),
                        .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 1.0)
                    ]), startPoint: .leading, endPoint: .trailing)
                    .frame(height: 0.5)

                    Text("JRR TOLKIEN")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .kerning(1.5)
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))

                    Text("LORD OF THE RINGS BY PG 203")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════
    // MARK: - STREAK WIDGET
    // MARK: - ═══════════════════════════════════════════════════════════

    private var streakSmallWidget: some View {
        ZStack {
            Color.black

            // Ambient gradient
            ambientAtmosphericGradient

            VStack(spacing: 8) {
                Spacer()

                // Number with blur effect
                ZStack {
                    // Glow/blur layer
                    Text("\(streakDays)")
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.6))
                        .blur(radius: 12)

                    // Sharp layer on top
                    Text("\(streakDays)")
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                Text("day streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()
            }
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════
    // MARK: - SHARED COMPONENTS
    // MARK: - ═══════════════════════════════════════════════════════════

    private var heroProgressRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                .frame(width: 140, height: 140)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: bookGradientColors.isEmpty ? [
                            DesignSystem.Colors.primaryAccent.opacity(0.8),
                            DesignSystem.Colors.primaryAccent
                        ] : [
                            bookGradientColors[1],
                            bookGradientColors[0]
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: (bookGradientColors.first ?? DesignSystem.Colors.primaryAccent).opacity(0.5),
                    radius: 6,
                    x: 0,
                    y: 0
                )

            // Percentage - MONOSPACED
            Text("\(Int(progress * 100))%")
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private var progressSliderView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Base track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: bookGradientColors.isEmpty ? [
                                DesignSystem.Colors.primaryAccent,
                                DesignSystem.Colors.primaryAccent.opacity(0.8)
                            ] : [
                                bookGradientColors[0],
                                bookGradientColors[1]
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 4)

                // Glass circle handle
                Circle()
                    .frame(width: 20, height: 20)
                    .glassEffect(.regular, in: Circle())
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: (geometry.size.width - 20) * progress)
            }
        }
        .frame(height: 20)
    }

    private var goalProgressSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Base track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: bookGradientColors.isEmpty ? [
                                DesignSystem.Colors.primaryAccent,
                                DesignSystem.Colors.primaryAccent.opacity(0.8)
                            ] : [
                                bookGradientColors[0],
                                bookGradientColors[1]
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * sessionProgress, height: 4)

                // Glass circle handle
                Circle()
                    .frame(width: 18, height: 18)
                    .glassEffect(.regular, in: Circle())
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: (geometry.size.width - 18) * sessionProgress)
            }
        }
        .frame(height: 18)
    }

    private var realAtmosphericGradient: some View {
        let colors = bookGradientColors.isEmpty ? defaultGradientColors : bookGradientColors

        // Enhance colors like BookAtmosphericGradientView
        let enhancedColors = colors.map { enhanceColor($0) }

        return LinearGradient(
            stops: [
                .init(color: enhancedColors[0].opacity(1.0), location: 0.0),
                .init(color: enhancedColors[1].opacity(0.8), location: 0.15),
                .init(color: enhancedColors[2].opacity(0.5), location: 0.3),
                .init(color: enhancedColors[3].opacity(0.3), location: 0.45),
                .init(color: Color.clear, location: 0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 40)
    }

    // EXACT same enhancement as BookAtmosphericGradientView
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Boost vibrancy and ensure minimum brightness
        let enhancedSaturation = min(saturation * 1.4, 1.0)
        let enhancedBrightness = max(brightness, 0.4)

        return Color(hue: Double(hue), saturation: Double(enhancedSaturation), brightness: Double(enhancedBrightness))
    }
}

// MARK: - Preview
#Preview {
    WidgetDesignLab()
        .modelContainer(for: [BookModel.self, CapturedQuote.self, CapturedNote.self])
}
