//
//  LockScreenWidgets.swift
//  EpilogueWidgets
//
//  Lock screen widgets — accessoryCircular and accessoryRectangular
//

import WidgetKit
import SwiftUI

// MARK: - Reading Progress (Circular)
struct ReadingProgressCircularView: View {
    let entry: CurrentReadingEntry

    var body: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "book.fill")
                .font(.system(size: 12))
        } currentValueLabel: {
            Text("\(Int(entry.progress * 100))")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Current Book (Rectangular)
struct CurrentBookRectangularView: View {
    let entry: CurrentReadingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "book.fill")
                    .font(.system(size: 9))
                    .widgetAccentable()
                Text(entry.bookTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }

            Text(entry.bookAuthor)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Progress bar
            ProgressView(value: entry.progress)
                .tint(.white)

            HStack {
                Text("\(entry.currentPage)/\(entry.totalPages)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(entry.progress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
    }
}

// MARK: - Inline accessory (shows on watch face complication line)
struct ReadingProgressInlineView: View {
    let entry: CurrentReadingEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "book.fill")
            Text("\(Int(entry.progress * 100))% — \(entry.bookTitle)")
        }
    }
}
