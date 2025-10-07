//
//  CurrentReadingWidget.swift
//  EpilogueWidgets
//
//  EXACT match to WidgetDesignLab
//

import WidgetKit
import SwiftUI

struct CurrentReadingProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrentReadingEntry {
        CurrentReadingEntry(
            date: Date(),
            bookTitle: "The Lord of the Rings",
            bookAuthor: "J.R.R. Tolkien",
            currentPage: 250,
            totalPages: 1178,
            coverURL: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentReadingEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct CurrentReadingEntry: TimelineEntry {
    let date: Date
    let bookTitle: String
    let bookAuthor: String
    let currentPage: Int
    let totalPages: Int
    let coverURL: String?

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }

    var pagesRemaining: Int {
        totalPages - currentPage
    }
}

// MARK: - Widget View
struct CurrentReadingWidgetView: View {
    var entry: CurrentReadingProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallView(entry: entry)
        case .systemMedium:
            MediumView(entry: entry)
        case .systemLarge:
            LargeView(entry: entry)
        default:
            SmallView(entry: entry)
        }
    }

    // MARK: - Small Widget
    struct SmallView: View {
        let entry: CurrentReadingEntry

        var body: some View {
            ZStack {
                Color.black

                atmosphericGradient

                VStack(spacing: 8) {
                    bookCoverPlaceholder(width: 55, height: 82, cornerRadius: 5)

                    Spacer()

                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 3)
                            .frame(width: 54, height: 54)

                        Circle()
                            .trim(from: 0, to: entry.progress)
                            .stroke(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .frame(width: 54, height: 54)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(entry.progress * 100))")
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Medium Widget
    struct MediumView: View {
        let entry: CurrentReadingEntry

        var body: some View {
            ZStack {
                Color.black

                atmosphericGradient

                HStack(spacing: 16) {
                    bookCoverPlaceholder(width: 75, height: 112, cornerRadius: 7)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.bookTitle)
                            .font(.custom("Georgia", size: 21))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                            .frame(height: 4)

                        progressSlider(progress: entry.progress)

                        Spacer()
                            .frame(height: 2)

                        HStack(spacing: 4) {
                            Text("\(entry.currentPage)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)

                            Text("/")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))

                            Text("\(entry.totalPages)")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))

                            Text("pages")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.leading, 2)
                        }
                    }
                    .frame(height: 112)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
        }
    }

    // MARK: - Large Widget
    struct LargeView: View {
        let entry: CurrentReadingEntry

        var body: some View {
            ZStack {
                Color.black

                atmosphericGradient

                VStack(spacing: 0) {
                    Spacer().frame(height: 32)

                    bookCoverPlaceholder(width: 70, height: 105, cornerRadius: 7)

                    Spacer().frame(height: 12)

                    VStack(spacing: 4) {
                        Text(entry.bookTitle)
                            .font(.custom("Georgia", size: 17))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(entry.bookAuthor)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .multilineTextAlignment(.center)

                    Spacer().frame(height: 20)

                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 3)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: entry.progress)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        enhancedGradientColors[1],
                                        enhancedGradientColors[0]
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .shadow(
                                color: enhancedGradientColors[0].opacity(0.5),
                                radius: 6,
                                x: 0,
                                y: 0
                            )

                        Text("\(Int(entry.progress * 100))%")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    Spacer().frame(height: 24)

                    HStack(alignment: .bottom, spacing: 40) {
                        VStack(spacing: 3) {
                            Text("\(entry.pagesRemaining)")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)

                            Text("pages left")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                        }

                        VStack(spacing: 3) {
                            Text("14h 46m")
                                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                .foregroundStyle(enhancedGradientColors[0])

                            Text("remaining")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }

                    Spacer().frame(height: 28)
                }
            }
        }
    }

    // MARK: - Shared Components
    private static func bookCoverPlaceholder(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.white.opacity(0.1))
            .frame(width: width, height: height)
            .overlay(
                Image(systemName: "book.fill")
                    .font(.system(size: width * 0.35))
                    .foregroundStyle(.white.opacity(0.3))
            )
            .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 4)
    }

    private static var atmosphericGradient: some View {
        let colors = enhancedGradientColors

        return LinearGradient(
            stops: [
                .init(color: colors[0].opacity(1.0), location: 0.0),
                .init(color: colors[1].opacity(0.8), location: 0.15),
                .init(color: colors[2].opacity(0.5), location: 0.3),
                .init(color: colors[3].opacity(0.3), location: 0.45),
                .init(color: Color.clear, location: 0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 40)
    }

    private static func progressSlider(progress: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 4)

                // Glass-style handle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.95), .white.opacity(0.8)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 10
                        )
                    )
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: (geometry.size.width - 20) * progress)
            }
        }
        .frame(height: 20)
    }

    // MARK: - Colors (matching WidgetDesignLab)
    private static var defaultGradientColors: [Color] {
        [
            Color(red: 1.0, green: 0.549, blue: 0.259),
            Color(red: 0.98, green: 0.4, blue: 0.2),
            Color(red: 0.9, green: 0.35, blue: 0.18),
            Color(red: 0.85, green: 0.3, blue: 0.15)
        ]
    }

    private static var enhancedGradientColors: [Color] {
        defaultGradientColors.map { enhanceColor($0) }
    }

    private static var gradientColors: [Color] {
        [enhancedGradientColors[0], enhancedGradientColors[1]]
    }

    // EXACT same enhancement as WidgetDesignLab
    private static func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let enhancedSaturation = min(saturation * 1.4, 1.0)
        let enhancedBrightness = max(brightness, 0.4)

        return Color(hue: Double(hue), saturation: Double(enhancedSaturation), brightness: Double(enhancedBrightness))
    }
}

struct CurrentReadingWidget: Widget {
    let kind: String = "CurrentReadingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentReadingProvider()) { entry in
            CurrentReadingWidgetView(entry: entry)
        }
        .configurationDisplayName("Currently Reading")
        .description("Track your reading progress")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
