//
//  AmbientModeWidget.swift
//  EpilogueWidgets
//
//  Ambient launcher - will use exported orb image
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
            if family == .systemSmall {
                VStack(spacing: 12) {
                    // Ambient orb (exported Metal shader)
                    if let uiImage = UIImage(named: "ambient-orb") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                    } else {
                        // Fallback: show placeholder
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text("No Orb\nImage")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            )
                    }

                    Text("Ask")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Epilogue")
                        .font(.custom("Georgia", size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else {
                HStack(spacing: 20) {
                    // Ambient orb (exported Metal shader)
                    if let uiImage = UIImage(named: "ambient-orb") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 110, height: 110)
                    } else {
                        // Fallback: show placeholder
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 110, height: 110)
                            .overlay(
                                Text("No Orb\nImage")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            )
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
        .containerBackground(for: .widget) {
            ZStack {
                Color.black
                Self.ambientAtmosphericGradient
            }
            .ignoresSafeArea()
        }
    }

    private static var ambientAtmosphericGradient: some View {
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
        .ignoresSafeArea()
    }

    private static var defaultGradientColors: [Color] {
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
