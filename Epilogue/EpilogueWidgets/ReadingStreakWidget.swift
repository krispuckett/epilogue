//
//  ReadingStreakWidget.swift
//  EpilogueWidgets
//
//  Shows daily reading streak
//

import WidgetKit
import SwiftUI

struct ReadingStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingStreakEntry {
        ReadingStreakEntry(date: Date(), streakDays: 7, readToday: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingStreakEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // TODO: Fetch real streak data from SwiftData
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct ReadingStreakEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let readToday: Bool
}

struct ReadingStreakWidgetView: View {
    var entry: ReadingStreakProvider.Entry

    var body: some View {
        VStack(spacing: 12) {
            // Flame icon
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: entry.readToday ? "flame.fill" : "flame")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 4) {
                Text("\(entry.streakDays)")
                    .font(.system(size: 32, weight: .bold))

                Text(entry.streakDays == 1 ? "Day Streak" : "Days Streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !entry.readToday {
                Text("Read today to continue")
                    .font(.caption2)
                    .foregroundStyle(.orange.opacity(0.8))
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ReadingStreakWidget: Widget {
    let kind: String = "ReadingStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingStreakProvider()) { entry in
            ReadingStreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Reading Streak")
        .description("Track your daily reading habit")
        .supportedFamilies([.systemSmall])
    }
}
