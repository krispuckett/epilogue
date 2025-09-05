import SwiftUI

struct OfflineQueueIndicator: View {
    @ObservedObject var queueManager = OfflineQueueManager.shared
    @State private var showingQueueSheet = false
    @State private var animateQueue = false
    
    var body: some View {
        if queueManager.queueDepth > 0 || !queueManager.isOnline {
            HStack(spacing: 8) {
                // Status icon
                Image(systemName: queueManager.isOnline ? "wifi" : "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(queueManager.isOnline ? .green : .orange)
                    .symbolEffect(.pulse, isActive: !queueManager.isOnline)
                
                // Queue badge
                if queueManager.queueDepth > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        
                        Text("\(queueManager.queueDepth)")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.orange.gradient)
                            .overlay(
                                Capsule()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                    .scaleEffect(animateQueue ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animateQueue)
                    .onAppear { animateQueue = true }
                    .onTapGesture {
                        showingQueueSheet = true
                    }
                }
                
                // Processing indicator
                if queueManager.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect()
            .sheet(isPresented: $showingQueueSheet) {
                QueuedQuestionsSheet()
            }
        }
    }
}

struct QueuedQuestionsSheet: View {
    @ObservedObject var queueManager = OfflineQueueManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var processedResponses: [(question: String, response: String, timestamp: Date)] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: queueManager.isOnline ? "wifi" : "wifi.slash")
                            .font(.largeTitle)
                            .foregroundStyle(queueManager.isOnline ? .green : .orange)
                        
                        Text(queueManager.isOnline ? "Online" : "Offline Mode")
                            .font(.headline)
                        
                        Text("\(queueManager.queueDepth) questions queued")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    
                    // Queued Questions
                    if !queueManager.queuedQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pending Questions")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(queueManager.queuedQuestions.sorted()) { question in
                                QueuedQuestionRow(question: question)
                            }
                        }
                    }
                    
                    // Processed Responses
                    if !processedResponses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Responses")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button("Clear") {
                                    queueManager.clearProcessedQuestions()
                                    loadProcessedResponses()
                                }
                                .font(.caption)
                            }
                            .padding(.horizontal)
                            
                            ForEach(processedResponses, id: \.question) { item in
                                ProcessedResponseRow(
                                    question: item.question,
                                    response: item.response,
                                    timestamp: item.timestamp
                                )
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Question Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            loadProcessedResponses()
        }
    }
    
    private func loadProcessedResponses() {
        processedResponses = queueManager.getProcessedResponses()
    }
}

struct QueuedQuestionRow: View {
    let question: QueuedQuestion
    @ObservedObject var queueManager = OfflineQueueManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.question ?? "")
                .font(.body)
                .lineLimit(2)
            
            HStack {
                Label(question.bookContext, systemImage: "book")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(question.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            if let error = question.processingError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal)
        .contextMenu {
            Button("Delete", role: .destructive) {
                queueManager.deleteQuestion(question)
            }
            
            if queueManager.isOnline {
                Button("Process Now") {
                    Task {
                        await queueManager.processQueue()
                    }
                }
            }
        }
    }
}

struct ProcessedResponseRow: View {
    let question: String
    let response: String
    let timestamp: Date
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(response)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 3)
            
            HStack {
                Text(timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Button(isExpanded ? "Show Less" : "Show More") {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.05))
        .glassEffect()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.green.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }
}