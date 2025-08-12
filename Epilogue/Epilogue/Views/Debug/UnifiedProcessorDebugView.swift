import SwiftUI

struct UnifiedProcessorDebugView: View {
    @ObservedObject private var processor = TrueAmbientProcessor.shared
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label("Processor", systemImage: "cpu")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // State indicator
                stateIndicator
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Current state details
                    stateDetails
                    
                    Divider()
                    
                    // Queue status
                    queueStatus
                    
                    Divider()
                    
                    // Recent saves
                    recentSaves
                    
                    // Debug info
                    Text(processor.getDebugInfo())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    private var stateIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            
            Text(stateText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var stateColor: Color {
        switch processor.currentState {
        case .listening: return .green
        case .detecting: return .yellow
        case .processing: return .orange
        case .saving: return .blue
        }
    }
    
    private var stateText: String {
        switch processor.currentState {
        case .listening: return "Listening"
        case .detecting(let content): 
            return "Detecting (\(content.prefix(20))...)"
        case .processing(let type, _): 
            return "Processing \(type)"
        case .saving: 
            return "Saving"
        }
    }
    
    private var stateDetails: some View {
        Group {
            switch processor.currentState {
            case .listening:
                Label("Waiting for speech input", systemImage: "mic")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .detecting(let content):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Analyzing content", systemImage: "waveform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(content)
                        .font(.caption2)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .padding(4)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(4)
                }
                
            case .processing(let type, let content):
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundColor(type.color)
                        Text("Processing \(String(describing: type).capitalized)")
                    }
                    .font(.caption)
                    
                    Text(content)
                        .font(.caption2)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .padding(4)
                        .background(type.color.opacity(0.1))
                        .cornerRadius(4)
                }
                
            case .saving(let item):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Saving to storage", systemImage: "arrow.down.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    HStack {
                        Image(systemName: item.type.icon)
                            .foregroundColor(item.type.color)
                            .font(.caption2)
                        
                        Text(item.text)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var queueStatus: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Queue: \(processor.processingQueue.count) items", systemImage: "list.bullet")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !processor.processingQueue.isEmpty {
                ForEach(processor.processingQueue.prefix(3), id: \.id) { item in
                    HStack(spacing: 4) {
                        Image(systemName: item.type.icon)
                            .foregroundColor(item.type.color)
                            .font(.caption2)
                        
                        Text(item.text)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if item.requiresAction {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                                .font(.caption2)
                        }
                    }
                    .padding(.leading, 16)
                }
            }
        }
    }
    
    private var recentSaves: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Recent: \(processor.recentlySaved.count) saved", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !processor.recentlySaved.isEmpty {
                ForEach(processor.recentlySaved.suffix(3).reversed(), id: \.id) { item in
                    HStack(spacing: 4) {
                        Image(systemName: item.type.icon)
                            .foregroundColor(item.type.color)
                            .font(.caption2)
                        
                        Text(item.text)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.0f%%", item.confidence * 100))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 16)
                }
            }
        }
    }
}

#Preview {
    UnifiedProcessorDebugView()
        .preferredColorScheme(.dark)
        .padding()
        .background(Color.black)
}