import SwiftUI

// MARK: - AI Model Indicator
struct AIModelIndicator: View {
    enum ModelType {
        case foundationModels
        case perplexity
        case hybrid
        
        var icon: String {
            switch self {
            case .foundationModels: return "brain"
            case .perplexity: return "globe"
            case .hybrid: return "arrow.triangle.branch"
            }
        }
        
        var label: String {
            switch self {
            case .foundationModels: return "On-Device"
            case .perplexity: return "Cloud"
            case .hybrid: return "Smart"
            }
        }
        
        var color: Color {
            switch self {
            case .foundationModels: return .blue
            case .perplexity: return .purple
            case .hybrid: return DesignSystem.Colors.primaryAccent
            }
        }
    }
    
    let modelType: ModelType
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: modelType.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(modelType.color)
                .symbolEffect(.pulse, value: isAnimating)
            
            Text(modelType.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(modelType.color.opacity(0.2), lineWidth: 0.5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever()) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Speed Indicator
struct ResponseSpeedIndicator: View {
    let responseTime: TimeInterval? // in seconds
    
    private var speedLabel: String {
        guard let time = responseTime else { return "..." }
        
        if time < 0.5 {
            return "⚡ Lightning"
        } else if time < 1.0 {
            return "🚀 Fast"
        } else if time < 2.0 {
            return "✓ Normal"
        } else {
            return "🐢 Slow"
        }
    }
    
    private var speedColor: Color {
        guard let time = responseTime else { return .gray }
        
        if time < 0.5 {
            return .green
        } else if time < 1.0 {
            return .blue
        } else if time < 2.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        if let time = responseTime {
            HStack(spacing: 4) {
                Text(speedLabel)
                    .font(.system(size: 9, weight: .medium))
                Text("(\(String(format: "%.1fs", time)))")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
            }
            .foregroundStyle(speedColor.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .glassEffect(in: Capsule())
        }
    }
}

// MARK: - Combined AI Status View
struct AIStatusView: View {
    @ObservedObject var aiService = AICompanionService.shared
    @ObservedObject var smartAI = SmartEpilogueAI.shared
    @State private var responseStartTime: Date?
    @State private var lastResponseTime: TimeInterval?
    
    private var currentModel: AIModelIndicator.ModelType {
        switch smartAI.currentMode {
        case .localOnly:
            return .foundationModels
        case .externalOnly:
            return .perplexity
        case .automatic:
            return .hybrid
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Model indicator
            AIModelIndicator(modelType: currentModel)
            
            // Speed indicator (if we have timing)
            if lastResponseTime != nil {
                ResponseSpeedIndicator(responseTime: lastResponseTime)
            }
        }
        .onChange(of: smartAI.isProcessing) { _, isProcessing in
            if isProcessing {
                responseStartTime = Date()
            } else if let start = responseStartTime {
                lastResponseTime = Date().timeIntervalSince(start)
                responseStartTime = nil
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        AIModelIndicator(modelType: .foundationModels)
        AIModelIndicator(modelType: .perplexity)
        AIModelIndicator(modelType: .hybrid)
        
        ResponseSpeedIndicator(responseTime: 0.3)
        ResponseSpeedIndicator(responseTime: 0.8)
        ResponseSpeedIndicator(responseTime: 1.5)
        ResponseSpeedIndicator(responseTime: 3.0)
        
        AIStatusView()
    }
    .padding()
    .background(Color.black)
}