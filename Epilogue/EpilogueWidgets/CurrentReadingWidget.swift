//
//  CurrentReadingWidget.swift
//  EpilogueWidgets
//
//  Simple reading progress widget
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
        // For now, just use placeholder data
        // TODO: Fetch real data from SwiftData once App Groups are set up
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Currently Reading")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(entry.bookTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)

                Spacer()

                // Progress ring
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 3)
                            .frame(width: 44, height: 44)

                        Circle()
                            .trim(from: 0, to: entry.progress)
                            .stroke(.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(entry.progress * 100))%")
                            .font(.system(size: 11, weight: .bold))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.currentPage)")
                            .font(.system(size: 16, weight: .bold))
                        Text("of \(entry.totalPages)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    // MARK: - Medium Widget
    struct MediumView: View {
        let entry: CurrentReadingEntry

        var body: some View {
            HStack(spacing: 16) {
                // Book cover placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.1))
                    .frame(width: 80, height: 110)
                    .overlay(
                        Image(systemName: "book.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.3))
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Currently Reading")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(entry.bookTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)

                    Text(entry.bookAuthor)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Page \(entry.currentPage)")
                                .font(.caption2)
                            Spacer()
                            Text("\(entry.pagesRemaining) left")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.15))

                                Capsule()
                                    .fill(.orange)
                                    .frame(width: geo.size.width * entry.progress)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    // MARK: - Large Widget
    struct LargeView: View {
        let entry: CurrentReadingEntry

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Currently Reading")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    // Book cover
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.1))
                        .frame(width: 100, height: 140)
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.3))
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.bookTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .lineLimit(2)

                        Text(entry.bookAuthor)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }

                Spacer()

                // Progress section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(Int(entry.progress * 100))%")
                                .font(.system(size: 32, weight: .bold))
                            Text("Complete")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("\(entry.pagesRemaining)")
                                .font(.system(size: 24, weight: .semibold))
                            Text("pages left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.15))

                            Capsule()
                                .fill(.orange)
                                .frame(width: geo.size.width * entry.progress)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
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
