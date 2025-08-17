import SwiftUI

// MARK: - Synthesized Response View
struct SynthesizedResponseView: View {
    let response: SynthesizedResponse
    let animationPhase: ResponseViewModel.AnimationPhase
    
    @State private var showCitations = false
    @State private var showInsights = true
    @State private var expandedContradiction: String?
    @State private var selectedFollowUp: String?
    
    @Namespace private var animationNamespace
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Key Insights Section (appears first)
                if !response.keyInsights.isEmpty {
                    InsightsSection(
                        insights: response.keyInsights,
                        isExpanded: showInsights,
                        animationPhase: animationPhase
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                
                // Main Response Text
                ResponseTextView(
                    text: response.text,
                    animationPhase: animationPhase
                )
                .animation(.easeInOut(duration: 0.3), value: response.text)
                
                // Confidence Indicator
                if response.confidence > 0 {
                    ConfidenceIndicator(
                        confidence: response.confidence,
                        sources: response.sources
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Contradictions Section
                if !response.contradictions.isEmpty {
                    ContradictionsSection(
                        contradictions: response.contradictions,
                        expandedContradiction: $expandedContradiction
                    )
                    .transition(.asymmetric(
                        insertion: .slide,
                        removal: .opacity
                    ))
                }
                
                // Citations Section
                if !response.citations.isEmpty {
                    CitationsSection(
                        citations: response.citations,
                        showCitations: $showCitations
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                
                // Media Embeds
                if !response.mediaEmbeds.isEmpty {
                    MediaEmbedsSection(embeds: response.mediaEmbeds)
                        .transition(.scale)
                }
                
                // Follow-up Questions
                if !response.followUpQuestions.isEmpty {
                    FollowUpQuestionsSection(
                        questions: response.followUpQuestions,
                        selectedQuestion: $selectedFollowUp
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .opacity
                    ))
                }
            }
            .padding()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: response.enhancementLevel)
    }
}

// MARK: - Response Text View
struct ResponseTextView: View {
    let text: String
    let animationPhase: ResponseViewModel.AnimationPhase
    
    @State private var displayedText = ""
    @State private var typewriterTask: Task<Void, Never>?
    
    var body: some View {
        Text(displayedText.isEmpty ? text : displayedText)
            .font(.system(.body, design: .serif))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .overlay(alignment: .topTrailing) {
                if animationPhase == .thinking {
                    ThinkingIndicator()
                        .padding(8)
                }
            }
            .onChange(of: text) { oldValue, newValue in
                // Animate text appearance for new content
                if oldValue.isEmpty && !newValue.isEmpty {
                    animateText(newValue)
                } else {
                    displayedText = newValue
                }
            }
            .onAppear {
                if !text.isEmpty && displayedText.isEmpty {
                    animateText(text)
                }
            }
    }
    
    private func animateText(_ fullText: String) {
        typewriterTask?.cancel()
        displayedText = ""
        
        typewriterTask = Task {
            // Fast typewriter effect for first 100 chars
            let words = fullText.split(separator: " ")
            
            for word in words {
                displayedText += word + " "
                
                // Variable speed based on content
                if displayedText.count < 100 {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                } else {
                    // Instant for rest
                    displayedText = fullText
                    break
                }
            }
        }
    }
}

// MARK: - Insights Section
struct InsightsSection: View {
    let insights: [String]
    let isExpanded: Bool
    let animationPhase: ResponseViewModel.AnimationPhase
    
    @State private var showInsights = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .symbolEffect(.pulse, value: animationPhase == .enhancing)
                
                Text("Key Insights")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            if isExpanded {
                ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        
                        Text(insight)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .transition(.asymmetric(
                                insertion: .push(from: .leading),
                                removal: .opacity
                            ))
                    }
                    .opacity(showInsights ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.3).delay(Double(index) * 0.1),
                        value: showInsights
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation {
                showInsights = true
            }
        }
    }
}

// MARK: - Confidence Indicator
struct ConfidenceIndicator: View {
    let confidence: Double
    let sources: [ResponseSource]
    
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Confidence bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(confidenceColor)
                            .frame(width: geometry.size.width * confidence)
                            .animation(.spring(), value: confidence)
                    }
                }
                .frame(height: 8)
                .frame(width: 100)
                
                Text("\(Int(confidence * 100))% confident")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showDetails.toggle()
                    }
                } label: {
                    Image(systemName: showDetails ? "chevron.up.circle" : "chevron.down.circle")
                        .foregroundStyle(.secondary)
                }
            }
            
            if showDetails {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sources, id: \.model) { source in
                        HStack {
                            Image(systemName: iconForSource(source.type))
                                .foregroundStyle(colorForSource(source.type))
                                .frame(width: 20)
                            
                            Text(source.model)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text("\(Int(source.latency))ms")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.asymmetric(
                    insertion: .push(from: .top),
                    removal: .push(from: .bottom)
                ))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    private var confidenceColor: Color {
        if confidence > 0.8 {
            return .green
        } else if confidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func iconForSource(_ type: ResponseSource.SourceType) -> String {
        switch type {
        case .foundationModel:
            return "brain"
        case .perplexity:
            return "globe"
        case .cache:
            return "clock.arrow.circlepath"
        }
    }
    
    private func colorForSource(_ type: ResponseSource.SourceType) -> Color {
        switch type {
        case .foundationModel:
            return .purple
        case .perplexity:
            return .blue
        case .cache:
            return .green
        }
    }
}

// MARK: - Citations Section
struct CitationsSection: View {
    let citations: [Citation]
    @Binding var showCitations: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    showCitations.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundStyle(.blue)
                    
                    Text("Sources (\(citations.count))")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: showCitations ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if showCitations {
                ForEach(Array(citations.enumerated()), id: \.element.id) { index, citation in
                    CitationRow(citation: citation, index: index + 1)
                        .transition(.asymmetric(
                            insertion: .slide,
                            removal: .opacity
                        ))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Citation Row
struct CitationRow: View {
    let citation: Citation
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Citation number
            Text("\(index)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(credibilityColor))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(citation.source)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !citation.text.isEmpty {
                    Text(citation.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                if let url = citation.url {
                    Link(destination: URL(string: url)!) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("View source")
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Credibility score
            VStack {
                Image(systemName: credibilityIcon)
                    .foregroundStyle(credibilityColor)
                Text("\(Int(citation.credibilityScore * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var credibilityColor: Color {
        if citation.credibilityScore > 0.8 {
            return .green
        } else if citation.credibilityScore > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var credibilityIcon: String {
        if citation.credibilityScore > 0.8 {
            return "checkmark.shield.fill"
        } else if citation.credibilityScore > 0.6 {
            return "exclamationmark.shield.fill"
        } else {
            return "xmark.shield.fill"
        }
    }
}

// MARK: - Contradictions Section
struct ContradictionsSection: View {
    let contradictions: [Contradiction]
    @Binding var expandedContradiction: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.orange)
                
                Text("Different Perspectives")
                    .font(.headline)
            }
            
            ForEach(contradictions, id: \.topic) { contradiction in
                ContradictionCard(
                    contradiction: contradiction,
                    isExpanded: expandedContradiction == contradiction.topic
                ) {
                    withAnimation {
                        expandedContradiction = expandedContradiction == contradiction.topic ? nil : contradiction.topic
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Contradiction Card
struct ContradictionCard: View {
    let contradiction: Contradiction
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                HStack {
                    Text(contradiction.topic)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Label(contradiction.localResponse, systemImage: "book.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    
                    Label(contradiction.webResponse, systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    Text(contradiction.resolution)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.leading, 16)
                .transition(.asymmetric(
                    insertion: .push(from: .top),
                    removal: .push(from: .bottom)
                ))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.02))
        )
    }
}

// MARK: - Follow-up Questions Section
struct FollowUpQuestionsSection: View {
    let questions: [String]
    @Binding var selectedQuestion: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You might also ask:")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ForEach(questions, id: \.self) { question in
                questionButton(for: question)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    @ViewBuilder
    private func questionButton(for question: String) -> some View {
        let isSelected = selectedQuestion == question
        
        Button {
            withAnimation {
                selectedQuestion = question
            }
        } label: {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(Color.accentColor)
                
                Text(question)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(questionBackground)
            .overlay(questionOverlay(isSelected: isSelected))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var questionBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.accentColor.opacity(0.05))
    }
    
    private func questionOverlay(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
                isSelected ? Color.accentColor : Color.clear,
                lineWidth: 2
            )
    }
}

// MARK: - Media Embeds Section
struct MediaEmbedsSection: View {
    let embeds: [MediaEmbed]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(embeds, id: \.url) { embed in
                    MediaEmbedCard(embed: embed)
                }
            }
        }
    }
}

// MARK: - Media Embed Card
struct MediaEmbedCard: View {
    let embed: MediaEmbed
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Placeholder for media
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 200, height: 150)
                .overlay(
                    Image(systemName: iconForMediaType(embed.type))
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                )
            
            if let caption = embed.caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 200)
    }
    
    private func iconForMediaType(_ type: MediaEmbed.MediaType) -> String {
        switch type {
        case .image:
            return "photo"
        case .video:
            return "play.rectangle"
        case .chart:
            return "chart.bar"
        case .map:
            return "map"
        }
    }
}

// MARK: - Thinking Indicator
struct ThinkingIndicator: View {
    @State private var dotCount = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .opacity(dotCount > index ? 1 : 0.3)
            }
        }
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation {
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}