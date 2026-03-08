import SwiftUI
import SwiftData

// MARK: - Book DNA Stats View
/// Developer view showing all BookDNA profiles and their similarity recommendations.
/// Accessible via Gandalf Mode → New Features Lab.

struct BookDNAStatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BookDNA.lastUpdated, order: .reverse) private var allDNAs: [BookDNA]

    @State private var selectedDNA: BookDNA?
    @State private var recommendations: [(bookTitle: String, bookAuthor: String, similarity: Double, reason: String)] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientChatGradientView()
                    .opacity(0.4)
                    .ignoresSafeArea(.all)

                Color.black.opacity(0.15)
                    .ignoresSafeArea(.all)

                List {
                    if allDNAs.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "leaf")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("No Book DNA profiles yet")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("DNA is generated for books with reading sessions, notes, or highlights.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    } else {
                        Section {
                            Text("\(allDNAs.count) book\(allDNAs.count == 1 ? "" : "s") profiled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(allDNAs, id: \.id) { dna in
                            Section {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Title
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(dna.bookTitle)
                                                .font(.headline)
                                            Text(dna.bookAuthor)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        // Resonance badge
                                        Text(String(format: "%.0f%%", dna.personalResonance * 100))
                                            .font(.caption.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(resonanceColor(dna.personalResonance).opacity(0.2))
                                            .foregroundStyle(resonanceColor(dna.personalResonance))
                                            .clipShape(Capsule())
                                    }

                                    Divider()

                                    // Stats row
                                    HStack(spacing: 16) {
                                        statPill("Sessions", "\(dna.sessionCount)")
                                        statPill("Quotes", "\(dna.totalHighlights)")
                                        statPill("Notes", "\(dna.totalNotes)")
                                        statPill("Pace", dna.paceProfile)
                                    }

                                    // Reading time
                                    if dna.totalReadingMinutes > 0 {
                                        HStack {
                                            Image(systemName: "clock")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(String(format: "%.0f min total · %.0f min avg/session", dna.totalReadingMinutes, dna.averageSessionMinutes))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    // Themes
                                    if !dna.themeWeights.isEmpty {
                                        FlowLayout(spacing: 4) {
                                            ForEach(dna.themeWeights.prefix(6), id: \.self) { theme in
                                                let key = theme.split(separator: ":").first.map(String.init) ?? theme
                                                Text(key)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(.green.opacity(0.15))
                                                    .foregroundStyle(.green)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }

                                    // Tone tags
                                    if !dna.toneTags.isEmpty {
                                        FlowLayout(spacing: 4) {
                                            ForEach(dna.toneTags.prefix(5), id: \.self) { tone in
                                                Text(tone)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(.purple.opacity(0.15))
                                                    .foregroundStyle(.purple)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }

                                    // Memory clusters
                                    if !dna.memoryClusters.isEmpty {
                                        HStack {
                                            Image(systemName: "brain")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(dna.memoryClusters.prefix(4).joined(separator: " · "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    // Density meters
                                    HStack(spacing: 12) {
                                        densityMeter("Idea", dna.ideaDensity, color: .cyan)
                                        densityMeter("Discussion", dna.discussionEnergy, color: .orange)
                                        densityMeter("Resonance", dna.personalResonance, color: .pink)
                                    }

                                    // Recommendations button
                                    Button {
                                        selectedDNA = dna
                                        recommendations = PersonalRecommendationEngine.shared.getRecommendations(
                                            for: dna.bookModelId,
                                            modelContext: modelContext
                                        )
                                    } label: {
                                        Label("Find Similar Books", systemImage: "arrow.triangle.branch")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }

                                    // Show recommendations inline if this is selected
                                    if selectedDNA?.id == dna.id {
                                        if recommendations.isEmpty {
                                            Text("No similar books found (need more DNA profiles)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(.top, 4)
                                        } else {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("Similar books for you:")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.green)
                                                ForEach(recommendations, id: \.bookTitle) { rec in
                                                    HStack {
                                                        VStack(alignment: .leading) {
                                                            Text(rec.bookTitle)
                                                                .font(.caption.bold())
                                                            Text(rec.reason)
                                                                .font(.caption2)
                                                                .foregroundStyle(.secondary)
                                                        }
                                                        Spacer()
                                                        Text(String(format: "%.0f%%", rec.similarity * 100))
                                                            .font(.caption2.bold())
                                                            .foregroundStyle(.green)
                                                    }
                                                }
                                            }
                                            .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Book DNA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func statPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func densityMeter(_ label: String, _ value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            ProgressView(value: value)
                .tint(color)
                .frame(width: 60)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func resonanceColor(_ value: Double) -> Color {
        switch value {
        case 0.7...: return .green
        case 0.4..<0.7: return .orange
        default: return .secondary
        }
    }
}
// Uses FlowLayout from SessionInsightCards.swift
