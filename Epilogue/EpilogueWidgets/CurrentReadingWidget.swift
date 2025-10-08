//
//  CurrentReadingWidget.swift
//  EpilogueWidgets
//
//  EXACT match to WidgetDesignLab - FIXED
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
            coverURL: nil,
            gradientColors: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentReadingEntry) -> ()) {
        let entry = fetchCurrentBook() ?? placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = fetchCurrentBook() ?? placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }

    private func fetchCurrentBook() -> CurrentReadingEntry? {
        guard let bookData = WidgetDataHelper.shared.getCurrentBook() else {
            return nil
        }

        return CurrentReadingEntry(
            date: Date(),
            bookTitle: bookData.title,
            bookAuthor: bookData.author,
            currentPage: bookData.currentPage,
            totalPages: bookData.totalPages,
            coverURL: bookData.coverURL,
            gradientColors: bookData.gradientColors
        )
    }
}

struct CurrentReadingEntry: TimelineEntry {
    let date: Date
    let bookTitle: String
    let bookAuthor: String
    let currentPage: Int
    let totalPages: Int
    let coverURL: String?
    let gradientColors: [String]?

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }

    var pagesRemaining: Int {
        totalPages - currentPage
    }

    var colors: [Color] {
        guard let gradientColors = gradientColors else {
            return defaultGradientColors
        }
        return gradientColors.compactMap { hexString in
            guard let rgb = Int(hexString.dropFirst(), radix: 16) else { return nil }
            let r = Double((rgb >> 16) & 0xFF) / 255.0
            let g = Double((rgb >> 8) & 0xFF) / 255.0
            let b = Double(rgb & 0xFF) / 255.0
            return Color(red: r, green: g, blue: b)
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
}

// MARK: - Widget View
struct CurrentReadingWidgetView: View {
    var entry: CurrentReadingProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
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
        .containerBackground(for: .widget) {
            ZStack {
                Color.black
                Self.atmosphericGradient(colors: entry.colors)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Small Widget
    struct SmallView: View {
        let entry: CurrentReadingEntry

        var body: some View {
            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                bookCoverView(entry: entry, width: 55, height: 82, cornerRadius: 5)

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
                                colors: [
                                    CurrentReadingWidgetView.enhanceColor(entry.colors[0]),
                                    CurrentReadingWidgetView.enhanceColor(entry.colors[1])
                                ],
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

                Spacer().frame(height: 20)
            }
        }
    }

    // MARK: - Medium Widget
    struct MediumView: View {
        let entry: CurrentReadingEntry

        var body: some View {
            HStack(spacing: 16) {
                bookCoverView(entry: entry, width: 75, height: 112, cornerRadius: 7)

                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.bookTitle)
                        .font(.custom("Georgia", size: 21))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                        .frame(height: 4)

                    CurrentReadingWidgetView.progressSlider(progress: entry.progress, colors: entry.colors)

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

    // MARK: - Large Widget
    struct LargeView: View {
        let entry: CurrentReadingEntry

        var body: some View {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                bookCoverView(entry: entry, width: 70, height: 105, cornerRadius: 7)

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
                                    CurrentReadingWidgetView.enhanceColor(entry.colors[1]),
                                    CurrentReadingWidgetView.enhanceColor(entry.colors[0])
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .shadow(
                            color: CurrentReadingWidgetView.enhanceColor(entry.colors[0]).opacity(0.5),
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
                            .foregroundStyle(CurrentReadingWidgetView.enhanceColor(entry.colors[0]))

                        Text("remaining")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }

                Spacer().frame(height: 28)
            }
        }
    }

    // MARK: - Shared Components
    private static func bookCoverView(entry: CurrentReadingEntry, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Group {
            if let coverPath = entry.coverURL,
               let uiImage = UIImage(contentsOfFile: coverPath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 4)
            } else {
                bookCoverPlaceholder(width: width, height: height, cornerRadius: cornerRadius)
            }
        }
    }

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

    private static func atmosphericGradient(colors: [Color]) -> some View {
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

    private static func progressSlider(progress: Double, colors: [Color]) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                enhanceColor(colors[0]),
                                enhanceColor(colors[1])
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 4)

                // Glass handle
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

    // MARK: - Colors
    static func enhanceColor(_ color: Color) -> Color {
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
