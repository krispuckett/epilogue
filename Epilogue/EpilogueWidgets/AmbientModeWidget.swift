//
//  AmbientModeWidget.swift
//  EpilogueWidgets
//
//  Quick launcher for Ambient Mode
//

import WidgetKit
import SwiftUI

struct AmbientModeProvider: TimelineProvider {
    func placeholder(in context: Context) -> AmbientModeEntry {
        AmbientModeEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AmbientModeEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct AmbientModeEntry: TimelineEntry {
    let date: Date
}

struct AmbientModeWidgetView: View {
    var entry: AmbientModeProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Link(destination: URL(string: "epilogue://ambient")!) {
            VStack(spacing: 12) {
                // Ambient orb placeholder
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.8, blue: 0.4),
                                    Color(red: 1.0, green: 0.549, blue: 0.259),
                                    Color(red: 0.8, green: 0.4, blue: 0.1)
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 40
                            )
                        )
                        .frame(width: 60, height: 60)
                        .blur(radius: 8)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }

                if family != .systemSmall {
                    VStack(spacing: 4) {
                        Text("Ambient Mode")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Start a reading session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct AmbientModeWidget: Widget {
    let kind: String = "AmbientModeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AmbientModeProvider()) { entry in
            AmbientModeWidgetView(entry: entry)
        }
        .configurationDisplayName("Ambient Mode")
        .description("Quick launch ambient reading")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
