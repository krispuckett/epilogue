import SwiftUI

struct TranscriptionDebugView: View {
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @StateObject private var pipeline = AmbientIntelligencePipeline()
    @StateObject private var adaptiveQuality = AdaptiveQualityManager()
    @State private var showPerformanceDetails = false
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Tab Selection
            Picker("Debug Section", selection: $selectedTab) {
                Text("Transcription").tag(0)
                Text("Intelligence").tag(1)
                Text("Performance").tag(2)
                Text("Quality").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            ScrollView {
                switch selectedTab {
                case 0:
                    transcriptionComparisonView
                case 1:
                    intelligenceResultsView
                case 2:
                    performanceMetricsView
                case 3:
                    qualityControlView
                default:
                    EmptyView()
                }
            }
        }
        .background(Color.black)
        .foregroundStyle(.white)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Transcription Debug")
                    .font(.title2.bold())
                
                HStack {
                    Circle()
                        .fill(voiceManager.isListening ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(voiceManager.isListening ? "Recording" : "Not Recording")
                        .font(.caption)
                        .foregroundStyle(voiceManager.isListening ? .green : .secondary)
                    
                    if voiceManager.isListening {
                        Text("• \(voiceManager.recognitionState.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !voiceManager.transcribedText.isEmpty {
                    Text("Apple: \(voiceManager.transcribedText)")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.blue)
                }
                
                if !voiceManager.whisperTranscribedText.isEmpty {
                    Text("Whisper: \(voiceManager.whisperTranscribedText)")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
            
            // Test button
            Button(action: {
                if voiceManager.isListening {
                    voiceManager.stopListening()
                } else {
                    voiceManager.startAmbientListening()
                }
            }) {
                Label(
                    voiceManager.isListening ? "Stop" : "Start",
                    systemImage: voiceManager.isListening ? "stop.circle.fill" : "mic.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(voiceManager.isListening ? .red : .green)
            }
            .buttonStyle(.bordered)
            
            // Confidence indicator
            ConfidenceGauge(value: pipeline.confidence)
                .frame(width: 60, height: 60)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Transcription Comparison
    
    private var transcriptionComparisonView: some View {
        VStack(spacing: 16) {
            if let result = pipeline.latestResult {
                // Whisper Result
                DebugCard(title: "WhisperKit", icon: "waveform.circle") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.transcription.whisperText.isEmpty ? "No transcription" : result.transcription.whisperText)
                            .font(.system(.body, design: .serif))
                        
                        HStack {
                            Label("\(String(format: "%.1f%%", result.transcription.confidence * 100))", systemImage: "checkmark.shield")
                                .font(.caption)
                                .foregroundStyle(.green)
                            
                            Spacer()
                            
                            Label("\(String(format: "%.2fs", result.transcription.processingTime))", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                
                // Apple Result
                DebugCard(title: "Apple Speech", icon: "mic.circle") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.transcription.appleText.isEmpty ? "No transcription" : result.transcription.appleText)
                            .font(.system(.body, design: .serif))
                        
                        HStack {
                            Label("Built-in", systemImage: "apple.logo")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            
                            Spacer()
                            
                            Label("\(String(format: "%.0fms", pipeline.processingMetrics.appleLatency * 1000))", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                
                // Final Result
                DebugCard(title: "Final Transcription", icon: "text.bubble", highlight: true) {
                    Text(result.transcription.finalText)
                        .font(.system(.body, design: .serif))
                        .fontWeight(.medium)
                }
                
                // Differences
                if result.transcription.whisperText != result.transcription.appleText {
                    DifferenceView(
                        text1: result.transcription.whisperText,
                        text2: result.transcription.appleText
                    )
                }
            } else {
                EmptyStateView(
                    icon: "mic.slash",
                    title: "No Transcription Yet",
                    subtitle: "Start speaking to see results"
                )
            }
        }
        .padding()
    }
    
    // MARK: - Intelligence Results
    
    private var intelligenceResultsView: some View {
        VStack(spacing: 16) {
            if let result = pipeline.latestResult {
                // Intent
                DebugCard(title: "Detected Intent", icon: "brain") {
                    HStack {
                        Text(result.intent.rawValue)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(result.intent.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Entities
                if !result.entities.isEmpty {
                    DebugCard(title: "Extracted Entities", icon: "tag.circle") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(result.entities, id: \.text) { entity in
                                EntityRow(entity: entity)
                            }
                        }
                    }
                }
                
                // Sentiment
                DebugCard(title: "Sentiment Analysis", icon: "face.smiling") {
                    SentimentBars(sentiment: result.sentiment)
                        .frame(height: 120)
                }
                
                // Suggested Action
                if result.suggestedAction.type != .none {
                    DebugCard(title: "Suggested Action", icon: "lightbulb", highlight: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(result.suggestedAction.title)
                                .font(.headline)
                            
                            Text(result.suggestedAction.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                UrgencyBadge(urgency: result.suggestedAction.urgency)
                                Spacer()
                            }
                        }
                    }
                }
            } else {
                EmptyStateView(
                    icon: "brain",
                    title: "No Intelligence Results",
                    subtitle: "Waiting for transcription"
                )
            }
        }
        .padding()
    }
    
    // MARK: - Performance Metrics
    
    private var performanceMetricsView: some View {
        VStack(spacing: 16) {
            // Latency Breakdown
            DebugCard(title: "Processing Latency", icon: "speedometer") {
                VStack(alignment: .leading, spacing: 12) {
                    LatencyBar(label: "Audio", value: pipeline.processingMetrics.audioLatency, maxValue: 0.1)
                    LatencyBar(label: "Whisper", value: pipeline.processingMetrics.whisperLatency, maxValue: 10.0)
                    LatencyBar(label: "Apple", value: pipeline.processingMetrics.appleLatency, maxValue: 1.0)
                    LatencyBar(label: "Models", value: pipeline.processingMetrics.modelsLatency, maxValue: 0.5)
                }
                .frame(height: 200)
            }
            
            // Performance Stats
            DebugCard(title: "Performance Stats", icon: "chart.line.uptrend.xyaxis") {
                VStack(spacing: 12) {
                    StatRow(label: "Audio Processing", value: "\(Int(pipeline.processingMetrics.audioLatency * 1000))ms")
                    StatRow(label: "Whisper", value: "\(Int(pipeline.processingMetrics.whisperLatency * 1000))ms")
                    StatRow(label: "Apple Speech", value: "\(Int(pipeline.processingMetrics.appleLatency * 1000))ms")
                    StatRow(label: "Foundation Models", value: "\(Int(pipeline.processingMetrics.modelsLatency * 1000))ms")
                    Divider()
                    StatRow(label: "Total Latency", value: "\(Int(pipeline.processingMetrics.totalLatency * 1000))ms", highlight: true)
                }
            }
            
            // Battery Impact
            DebugCard(title: "Battery Impact", icon: "battery.75") {
                BatteryImpactView(impact: adaptiveQuality.getBatteryImpact())
            }
            
            // Performance Report
            if showPerformanceDetails {
                DebugCard(title: "Detailed Report", icon: "doc.text") {
                    Text(PerformanceProfiler.shared.getReport())
                        .font(.system(.caption, design: .monospaced))
                }
            }
            
            Button {
                showPerformanceDetails.toggle()
            } label: {
                Label(
                    showPerformanceDetails ? "Hide Details" : "Show Details",
                    systemImage: showPerformanceDetails ? "chevron.up" : "chevron.down"
                )
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Quality Control
    
    private var qualityControlView: some View {
        VStack(spacing: 16) {
            // Current Quality
            DebugCard(title: "Quality Level", icon: "slider.horizontal.3") {
                VStack(spacing: 12) {
                    HStack {
                        Text(adaptiveQuality.currentQuality.rawValue)
                            .font(.headline)
                        
                        Spacer()
                        
                        QualityIndicator(level: adaptiveQuality.currentQuality)
                    }
                    
                    Text(adaptiveQuality.currentQuality.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Battery Status
            DebugCard(title: "Battery Status", icon: "battery.100") {
                VStack(spacing: 12) {
                    BatteryLevelView(level: adaptiveQuality.batteryLevel)
                    
                    if adaptiveQuality.isLowPowerMode {
                        Label("Low Power Mode Active", systemImage: "battery.25")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            // Thermal State
            DebugCard(title: "Thermal State", icon: "thermometer") {
                ThermalStateView(state: adaptiveQuality.thermalState)
            }
            
            // Current Settings
            DebugCard(title: "Current Settings", icon: "gearshape") {
                VStack(spacing: 8) {
                    SettingRow(label: "Whisper Model", value: adaptiveQuality.whisperModel)
                    SettingRow(label: "Processing Interval", value: "\(Int(adaptiveQuality.processingInterval))s")
                    SettingRow(label: "VAD Enabled", value: adaptiveQuality.enableVAD ? "Yes" : "No")
                    SettingRow(label: "Parallel Processing", value: adaptiveQuality.enableParallelProcessing ? "Yes" : "No")
                    SettingRow(label: "Max Tasks", value: "\(adaptiveQuality.maxConcurrentTasks)")
                }
            }
            
            // Manual Controls
            DebugCard(title: "Manual Override", icon: "hand.raised") {
                VStack(spacing: 12) {
                    ForEach(AdaptiveQualityManager.QualityLevel.allCases, id: \.self) { level in
                        Button {
                            adaptiveQuality.forceQualityLevel(level)
                        } label: {
                            HStack {
                                Text(level.rawValue)
                                Spacer()
                                if adaptiveQuality.currentQuality == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Component Views

struct DebugCard<Content: View>: View {
    let title: String
    let icon: String
    var highlight: Bool = false
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(highlight ? .orange : .blue)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(highlight ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
    }
}

struct ConfidenceGauge: View {
    let value: Float
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: CGFloat(value))
                .stroke(
                    value > 0.8 ? Color.green :
                    value > 0.6 ? Color.orange : Color.red,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(value * 100))%")
                .font(.caption.bold())
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }
}

// MARK: - Additional Components

struct LatencyBar: View {
    let label: String
    let value: TimeInterval
    let maxValue: TimeInterval
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int(value * 1000))ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(min(value / maxValue, 1.0)))
                }
            }
            .frame(height: 8)
        }
    }
}

struct SentimentBars: View {
    let sentiment: FoundationModelsProcessor.SentimentScore
    
    var body: some View {
        VStack(spacing: 12) {
            SentimentBar(label: "Positive", value: sentiment.positive, color: .green)
            SentimentBar(label: "Neutral", value: sentiment.neutral, color: .gray)
            SentimentBar(label: "Negative", value: sentiment.negative, color: .red)
        }
    }
}

struct SentimentBar: View {
    let label: String
    let value: Float
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 60, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value))
                }
            }
            .frame(height: 8)
            
            Text("\(Int(value * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

struct EntityRow: View {
    let entity: FoundationModelsProcessor.ExtractedEntity
    
    var body: some View {
        HStack {
            Label(entity.type.rawValue, systemImage: entityIcon)
                .font(.caption)
                .foregroundStyle(.blue)
            
            Text(entity.text)
                .font(.caption)
            
            Spacer()
            
            Text("\(Int(entity.confidence * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
    
    private var entityIcon: String {
        switch entity.type {
        case .person: return "person.circle"
        case .location: return "location.circle"
        case .quote: return "quote.bubble"
        case .pageNumber: return "book.pages"
        case .concept: return "lightbulb.circle"
        case .bookTitle: return "book.circle"
        case .author: return "person.text.rectangle"
        case .time: return "clock"
        }
    }
}

struct UrgencyBadge: View {
    let urgency: Urgency
    
    var body: some View {
        Text(urgency.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(urgencyColor.opacity(0.2))
                    .overlay(
                        Capsule()
                            .stroke(urgencyColor, lineWidth: 1)
                    )
            )
            .foregroundStyle(urgencyColor)
    }
    
    private var urgencyColor: Color {
        switch urgency {
        case .immediate: return .red
        case .normal: return .orange
        case .low: return .gray
        }
    }
}

struct DifferenceView: View {
    let text1: String
    let text2: String
    
    var body: some View {
        DebugCard(title: "Transcription Differences", icon: "doc.text.magnifyingglass") {
            Text("Differences between Whisper and Apple transcriptions")
                .font(.caption)
                .foregroundStyle(.secondary)
            // Could implement actual diff highlighting here
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(highlight ? .primary : .secondary)
            
            Spacer()
            
            Text(value)
                .font(highlight ? .caption.bold() : .caption)
                .monospacedDigit()
                .foregroundStyle(highlight ? .orange : .primary)
        }
    }
}

struct BatteryImpactView: View {
    let impact: Float
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Current Impact")
                    .font(.caption)
                
                Spacer()
                
                Text("\(Int(impact * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(impactColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(impactColor)
                        .frame(width: geometry.size.width * CGFloat(impact))
                }
            }
            .frame(height: 8)
        }
    }
    
    private var impactColor: Color {
        if impact < 0.3 { return .green }
        else if impact < 0.6 { return .orange }
        else { return .red }
    }
}

struct QualityIndicator: View {
    let level: AdaptiveQualityManager.QualityLevel
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                Circle()
                    .fill(index < qualityIndex ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var qualityIndex: Int {
        switch level {
        case .maximum: return 4
        case .balanced: return 3
        case .efficient: return 2
        case .minimal: return 1
        }
    }
}

struct BatteryLevelView: View {
    let level: Float
    
    var body: some View {
        HStack {
            Image(systemName: batteryIcon)
                .font(.title2)
                .foregroundStyle(batteryColor)
            
            Text("\(Int(level * 100))%")
                .font(.headline)
                .monospacedDigit()
            
            Spacer()
        }
    }
    
    private var batteryIcon: String {
        if level > 0.75 { return "battery.100" }
        else if level > 0.5 { return "battery.75" }
        else if level > 0.25 { return "battery.50" }
        else { return "battery.25" }
    }
    
    private var batteryColor: Color {
        if level > 0.5 { return .green }
        else if level > 0.2 { return .orange }
        else { return .red }
    }
}

struct ThermalStateView: View {
    let state: ProcessInfo.ThermalState
    
    var body: some View {
        HStack {
            Image(systemName: "thermometer")
                .foregroundStyle(thermalColor)
            
            Text(thermalText)
                .font(.caption)
            
            Spacer()
            
            if state != .nominal {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private var thermalText: String {
        switch state {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    private var thermalColor: Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }
}

struct SettingRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
        }
    }
}

// MARK: - Preview

struct TranscriptionDebugView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptionDebugView()
            .preferredColorScheme(.dark)
    }
}