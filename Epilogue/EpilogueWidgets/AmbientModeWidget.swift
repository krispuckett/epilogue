//
//  AmbientModeWidget.swift
//  EpilogueWidgets
//
//  EXACT match to WidgetDesignLab ambient designs
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
            ZStack {
                Color.black

                // Ambient atmospheric gradient (NOT enhanced)
                ambientAtmosphericGradient

                if family == .systemSmall {
                    // Small widget - EXACT match to WidgetDesignLab
                    VStack(spacing: 12) {
                        // Orb (can't use Metal shader in widgets, use radial gradient)
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
                                        startRadius: 15,
                                        endRadius: 40
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .blur(radius: 8)

                            Image(systemName: "mic.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }

                        Text("Ask")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Epilogue")
                            .font(.custom("Georgia", size: 14))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    // Medium widget - EXACT match to WidgetDesignLab
                    HStack(spacing: 20) {
                        // Larger orb
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
                                        startRadius: 20,
                                        endRadius: 45
                                    )
                                )
                                .frame(width: 90, height: 90)
                                .blur(radius: 8)

                            Image(systemName: "mic.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                        }

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
