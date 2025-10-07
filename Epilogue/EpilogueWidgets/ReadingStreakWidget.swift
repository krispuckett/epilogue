//
//  ReadingStreakWidget.swift
//  EpilogueWidgets
//
//  EXACT match to WidgetDesignLab streak widget
//

import WidgetKit
import SwiftUI

struct ReadingStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingStreakEntry {
        ReadingStreakEntry(date: Date(), streakDays: 18)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingStreakEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct ReadingStreakEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
}

struct ReadingStreakWidgetView: View {
    var entry: ReadingStreakProvider.Entry

    var body: some View {
        ZStack {
            Color.black

            // Ambient gradient (same as ambient widget)
            ambientAtmosphericGradient

            VStack(spacing: 8) {
                Spacer()

                // Number with blur effect (glow) - EXACT from WidgetDesignLab
                ZStack {
                    // Glow/blur layer
                    Text("\(entry.streakDays)")
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.6))
                        .blur(radius: 12)

                    // Sharp layer on top
                    Text("\(entry.streakDays)")
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

    // EXACT ambient gradient from WidgetDesignLab (no color enhancement)
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

    private var defaultGradientColors: [Color] {
        [
            Color(red: 1.0, green: 0.549, blue: 0.259),
            Color(red: 0.98, green: 0.4, blue: 0.2),
            Color(red: 0.9, green: 0.35, blue: 0.18),
            Color(red: 0.85, green: 0.3, blue: 0.15)
        ]
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
