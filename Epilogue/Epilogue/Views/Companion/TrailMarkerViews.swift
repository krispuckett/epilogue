import SwiftUI

// MARK: - Trail Marker Card
/// Displays a trail marker left by your reading companion.

struct TrailMarkerCard: View {
    let marker: TrailMarker
    let isNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: marker.type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)

                Text(marker.authorDisplayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer()

                if let chapter = marker.chapterReference {
                    Text(chapter)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                } else if let page = marker.pageReference {
                    Text("p. \(page)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                if isNew {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DesignSystem.Colors.primaryAccent)
                        .clipShape(Capsule())
                }
            }

            // Content
            Group {
                switch marker.type {
                case .quote:
                    HStack(alignment: .top, spacing: 8) {
                        Text("\u{201C}")
                            .font(.custom("Georgia", size: 28))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .offset(y: -6)

                        Text(marker.content)
                            .font(.custom("Georgia", size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .italic()
                    }
                default:
                    Text(marker.content)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            Text(marker.createdAt, style: .relative)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textQuaternary)
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(isNew ? DesignSystem.Colors.primaryAccent.opacity(0.05) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .strokeBorder(isNew ? DesignSystem.Colors.primaryAccent.opacity(0.2) : Color.white.opacity(0.10), lineWidth: 0.5)
        )
    }
}

// MARK: - Trail Marker Discovery View

struct TrailMarkerDiscoveryView: View {
    let discovery: TrailMarkerDiscovery
    let onDismiss: () -> Void

    @State private var isVisible: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                        .frame(width: 72, height: 72)

                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                }

                VStack(spacing: 4) {
                    Text("Trail Marker Discovered")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("from \(discovery.marker.authorDisplayName)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                TrailMarkerCard(marker: discovery.marker, isNew: true)
                    .padding(.horizontal, 8)

                Button {
                    dismiss()
                } label: {
                    Text("Continue Reading")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.primaryAccent.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.3), lineWidth: 0.5))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            )
            .padding(24)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { isVisible = true }
            SensoryFeedback.success()
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) { isVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
    }
}

// MARK: - Leave Marker Sheet

struct LeaveMarkerSheet: View {
    let book: BookModel
    let companionship: SocialCompanionship
    let currentProgress: Double
    let onSave: (TrailMarker) -> Void
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var content: String = ""
    @State private var selectedType: TrailMarkerType = .thought
    @State private var chapter: String = ""
    @State private var isSaving: Bool = false
    @FocusState private var isContentFocused: Bool

    @AppStorage("userDisplayName") private var displayName: String = ""

    private var recipientName: String {
        companionship.companionDisplayName ?? companionship.ownerDisplayName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Solid dark background
                Color(red: 0.08, green: 0.08, blue: 0.09)
                    .ignoresSafeArea(.all)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Hero: Content input first
                        contentSection
                            .padding(.top, 8)

                        // Secondary: Type and chapter in a row
                        metadataSection

                        // Footer info
                        footerSection
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)

                // Sticky save button at bottom
                VStack {
                    Spacer()
                    saveButton
                }
            }
            .navigationTitle("Leave a Marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
    }

    // MARK: - Content Section (Hero)

    private var contentSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $content)
                .font(.custom("Georgia", size: 17))
                .foregroundStyle(.white.opacity(0.95))
                .scrollContentBackground(.hidden)
                .focused($isContentFocused)
                .frame(minHeight: 180)
                .padding(16)

            if content.isEmpty {
                Text(placeholderText)
                    .font(.custom("Georgia", size: 17))
                    .foregroundStyle(.white.opacity(0.3))
                    .allowsHitTesting(false)
                    .padding(16)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Metadata Section (Type + Chapter)

    private var metadataSection: some View {
        HStack(spacing: 12) {
            // Type picker as menu
            Menu {
                ForEach(TrailMarkerType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedType = type
                        }
                        SensoryFeedback.selection()
                    } label: {
                        Label(type.displayName, systemImage: type.icon)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedType.icon)
                        .font(.system(size: 13, weight: .medium))
                    Text(selectedType.displayName)
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            }

            // Chapter field
            HStack(spacing: 8) {
                Image(systemName: "bookmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))

                TextField("Chapter", text: $chapter)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye")
                .font(.system(size: 11))
            Text("\(recipientName) will discover this when they reach \(Int(currentProgress * 100))%")
                .font(.system(size: 12))
        }
        .foregroundStyle(DesignSystem.Colors.textQuaternary)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveMarker()
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Text("Leave Marker")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(content.isEmpty ? Color.white.opacity(0.05) : DesignSystem.Colors.primaryAccent.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(content.isEmpty ? Color.white.opacity(0.08) : DesignSystem.Colors.primaryAccent.opacity(0.4), lineWidth: 1)
            )
        }
        .disabled(content.isEmpty || isSaving)
        .opacity(content.isEmpty ? 0.5 : 1)
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0), Color(red: 0.08, green: 0.08, blue: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .allowsHitTesting(false)
        )
    }

    // MARK: - Helpers

    private var placeholderText: String {
        switch selectedType {
        case .thought: return "What are you thinking at this point?"
        case .quote: return "Paste a quote you want them to see"
        case .question: return "What should they think about here?"
        case .highlight: return "What moment stood out to you?"
        }
    }

    private func saveMarker() {
        isSaving = true
        SensoryFeedback.medium()

        Task {
            do {
                let userRecordName = try await SocialCompanionService.shared.getCurrentUserRecordName()
                let isOwner = companionship.ownerRecordName == userRecordName
                let authorName = isOwner ? companionship.ownerDisplayName : (companionship.companionDisplayName ?? displayName)

                let marker = try SocialCompanionService.shared.leaveTrailMarker(
                    in: companionship,
                    content: content,
                    type: selectedType,
                    progress: currentProgress,
                    chapter: chapter.isEmpty ? nil : chapter,
                    page: book.currentPage > 0 ? book.currentPage : nil,
                    authorDisplayName: authorName,
                    authorRecordName: userRecordName,
                    context: modelContext
                )

                await MainActor.run {
                    isSaving = false
                    SensoryFeedback.success()
                    onSave(marker)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    SensoryFeedback.error()
                }
            }
        }
    }
}

// MARK: - Trail Markers List

struct TrailMarkersList: View {
    let companionship: SocialCompanionship
    let currentProgress: Double
    let isOwner: Bool

    var visibleMarkers: [TrailMarker] {
        companionship.visibleTrailMarkers(forProgress: currentProgress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TRAIL MARKERS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            if visibleMarkers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 24))
                        .foregroundStyle(DesignSystem.Colors.textQuaternary)

                    Text("No trail markers yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("Leave one for your companion to discover")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(Color.white.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                )
            } else {
                ForEach(visibleMarkers, id: \.id) { marker in
                    TrailMarkerCard(
                        marker: marker,
                        isNew: marker.revealedAt != nil && marker.revealedAt! > Date().addingTimeInterval(-86400)
                    )
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Leave Marker Sheet") {
    LeaveMarkerSheet(
        book: BookModel(id: "123", title: "Test Book", author: "Author"),
        companionship: {
            let c = SocialCompanionship(
                book: BookModel(id: "123", title: "Test", author: "Test"),
                ownerDisplayName: "Kris",
                ownerRecordName: "owner123"
            )
            c.companionDisplayName = "Sarah"
            return c
        }(),
        currentProgress: 0.45,
        onSave: { _ in },
        onDismiss: {}
    )
}
