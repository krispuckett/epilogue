import SwiftUI
import Combine

struct OptimizedAIQueryView: View {
    @StateObject private var viewModel: OptimizedAIQueryViewModel
    @State private var query = ""
    @State private var showingUpgradePrompt = false
    @State private var showingSimilarQueries = false
    @State private var selectedSimilarQuery: CachedQueryResult?
    @State private var isProgressiveLoading = false
    @State private var progressiveStage: ProgressiveStage = .initial
    
    let book: Book
    
    init(book: Book) {
        self.book = book
        self._viewModel = StateObject(wrappedValue: OptimizedAIQueryViewModel(book: book))
    }
    
    enum ProgressiveStage {
        case initial, expanded, complete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Quota Display
            QuotaHeaderView(
                queriesRemaining: viewModel.queriesRemaining,
                isPro: viewModel.isPro,
                onUpgradeTap: { showingUpgradePrompt = true }
            )
            
            // Main Content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Response Area
                        if let response = viewModel.currentResponse {
                            ResponseCard(
                                response: response,
                                isFromCache: viewModel.isFromCache,
                                confidence: viewModel.cacheConfidence,
                                isLoading: viewModel.isLoading,
                                progressiveStage: progressiveStage
                            )
                            .id("response")
                        }
                        
                        // Similar Cached Queries
                        if !viewModel.similarQueries.isEmpty && !viewModel.isLoading {
                            SimilarQueriesSection(
                                queries: viewModel.similarQueries,
                                onSelect: { query in
                                    selectedSimilarQuery = query
                                    self.query = query.query
                                    viewModel.useCachedQuery(query)
                                }
                            )
                        }
                        
                        // Optimization Tips
                        if viewModel.showOptimizationTips {
                            OptimizationTipsCard(
                                currentQuery: query,
                                queryType: viewModel.queryType,
                                estimatedTokens: viewModel.estimatedTokens
                            )
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.currentResponse) { _, _ in
                    withAnimation {
                        proxy.scrollTo("response", anchor: .top)
                    }
                }
            }
            
            // Query Input
            QueryInputBar(
                query: $query,
                isLoading: viewModel.isLoading,
                canSubmit: viewModel.canSubmitQuery,
                onSubmit: submitQuery,
                onProgressiveTap: toggleProgressiveMode
            )
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingCacheStats() }) {
                        Label("Cache Stats", systemImage: "chart.bar")
                    }
                    
                    Button(action: { clearCache() }) {
                        Label("Clear Cache", systemImage: "trash")
                    }
                    
                    if viewModel.isPro {
                        Button(action: { exportConversation() }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView(
                queriesUsedToday: 20 - viewModel.queriesRemaining,
                onUpgrade: handleUpgrade
            )
        }
        .alert("Query Limit Reached", isPresented: $viewModel.showQuotaExceeded) {
            Button("View Upgrade Options") {
                showingUpgradePrompt = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've used all 20 free queries for today. Upgrade to Pro for unlimited queries and advanced features.")
        }
    }
    
    // MARK: - Actions
    
    private func submitQuery() {
        guard !query.isEmpty else { return }
        
        Task {
            if isProgressiveLoading {
                // Progressive loading mode
                progressiveStage = .initial
                await viewModel.submitQueryProgressive(query)
                
                // Simulate progressive loading stages
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    progressiveStage = .expanded
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    progressiveStage = .complete
                }
            } else {
                await viewModel.submitQuery(query)
            }
        }
    }
    
    private func toggleProgressiveMode() {
        isProgressiveLoading.toggle()
    }
    
    private func showingCacheStats() {
        // Navigate to cache stats
    }
    
    private func clearCache() {
        viewModel.clearCache()
    }
    
    private func exportConversation() {
        // Export functionality
    }
    
    private func handleUpgrade() {
        // Handle upgrade process
    }
}

// MARK: - Quota Header

struct QuotaHeaderView: View {
    let queriesRemaining: Int
    let isPro: Bool
    let onUpgradeTap: () -> Void
    
    var body: some View {
        HStack {
            if isPro {
                Label("Pro", systemImage: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.purple)
                Text("Unlimited Queries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 4) {
                    ForEach(0..<20) { index in
                        Circle()
                            .fill(index < queriesRemaining ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                
                Spacer()
                
                Text("\(queriesRemaining)/20")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(queriesRemaining < 5 ? .orange : .primary)
                
                if queriesRemaining < 5 {
                    Button("Upgrade") {
                        onUpgradeTap()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - Response Card

struct ResponseCard: View {
    let response: String
    let isFromCache: Bool
    let confidence: Double
    let isLoading: Bool
    let progressiveStage: OptimizedAIQueryView.ProgressiveStage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isFromCache {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.green)
                    Text("From Cache")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if confidence < 1.0 {
                        Text("(\(Int(confidence * 100))% match)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(progressiveText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(response)
                .font(.body)
                .animation(.easeInOut, value: response)
            
            if progressiveStage != .complete && !isFromCache {
                Button("Load More Details") {
                    // Trigger next stage
                }
                .font(.caption)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    var progressiveText: String {
        switch progressiveStage {
        case .initial:
            return "Getting quick answer..."
        case .expanded:
            return "Loading more details..."
        case .complete:
            return "Finalizing response..."
        }
    }
}

// MARK: - Similar Queries Section

struct SimilarQueriesSection: View {
    let queries: [CachedQueryResult]
    let onSelect: (CachedQueryResult) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                Text("Similar Questions")
                    .font(.headline)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(queries) { query in
                        SimilarQueryChip(
                            query: query,
                            onTap: { onSelect(query) }
                        )
                    }
                }
            }
        }
    }
}

struct SimilarQueryChip: View {
    let query: CachedQueryResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(query.query)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text("Instant")
                        .font(.caption2)
                    
                    Spacer()
                    
                    Text("\(Int(query.similarity * 100))%")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .padding(8)
            .frame(width: 180)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Optimization Tips

struct OptimizationTipsCard: View {
    let currentQuery: String
    let queryType: String?
    let estimatedTokens: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Optimization Tips")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let type = queryType {
                Text("Query type: \(type)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text("Estimated tokens: ~\(estimatedTokens)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if estimatedTokens > 2000 {
                Text("💡 Try breaking this into smaller questions for better caching")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Query Input Bar

struct QueryInputBar: View {
    @Binding var query: String
    let isLoading: Bool
    let canSubmit: Bool
    let onSubmit: () -> Void
    let onProgressiveTap: () -> Void
    
    @State private var isProgressiveEnabled = false
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onProgressiveTap) {
                Image(systemName: isProgressiveEnabled ? "bolt.fill" : "bolt")
                    .foregroundColor(isProgressiveEnabled ? .orange : .gray)
            }
            .buttonStyle(.plain)
            
            TextField("Ask about this book...", text: $query)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isLoading || !canSubmit)
                .onSubmit(onSubmit)
            
            Button(action: onSubmit) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSubmit && !query.isEmpty ? .blue : .gray)
                }
            }
            .disabled(!canSubmit || query.isEmpty || isLoading)
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - Upgrade Prompt

struct UpgradePromptView: View {
    let queriesUsedToday: Int
    let onUpgrade: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Upgrade to Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("You've used \(queriesUsedToday) of 20 free queries today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "infinity", text: "Unlimited queries")
                    FeatureRow(icon: "contextualmenu.and.cursorarrow", text: "Longer context windows")
                    FeatureRow(icon: "bubble.left.and.bubble.right", text: "Multi-turn conversations")
                    FeatureRow(icon: "doc.text.magnifyingglass", text: "Bulk book analysis")
                    FeatureRow(icon: "square.and.arrow.down", text: "Export conversation history")
                    FeatureRow(icon: "bolt.fill", text: "Priority processing")
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 12) {
                    Button(action: onUpgrade) {
                        Text("Upgrade for $9.99/month")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - View Model

class OptimizedAIQueryViewModel: ObservableObject {
    @Published var currentResponse: String?
    @Published var isLoading = false
    @Published var isFromCache = false
    @Published var cacheConfidence: Double = 0
    @Published var similarQueries: [CachedQueryResult] = []
    @Published var queriesRemaining: Int = 20
    @Published var isPro = false
    @Published var showQuotaExceeded = false
    @Published var canSubmitQuery = true
    @Published var showOptimizationTips = false
    @Published var queryType: String?
    @Published var estimatedTokens = 0
    
    private let book: Book
    private let optimizer = QueryOptimizationService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(book: Book) {
        self.book = book
        setupBindings()
    }
    
    private func setupBindings() {
        optimizer.$queriesRemainingToday
            .assign(to: &$queriesRemaining)
        
        optimizer.$isPro
            .assign(to: &$isPro)
    }
    
    func submitQuery(_ query: String) async {
        await MainActor.run {
            isLoading = true
            showOptimizationTips = true
        }
        
        do {
            let result = try await optimizer.optimizeQuery(query, for: book)
            
            switch result {
            case .cached(let response, let confidence):
                await MainActor.run {
                    self.currentResponse = response
                    self.isFromCache = true
                    self.cacheConfidence = confidence
                    self.isLoading = false
                }
                
            case .apiRequired(let context, let tokens):
                await MainActor.run {
                    self.estimatedTokens = tokens
                }
                
                // Make API call
                let response = await callPerplexityAPI(query: query, context: context)
                
                await MainActor.run {
                    self.currentResponse = response
                    self.isFromCache = false
                    self.isLoading = false
                }
                
                // Cache the response
                await optimizer.cacheResponse(
                    query: query,
                    response: response,
                    bookId: book.id,
                    bookTitle: book.title,
                    context: context,
                    tokensUsed: tokens,
                    responseTime: 2.0,
                    queryType: "general"
                )
                
                optimizer.consumeQuery()
                
            case .quotaExceeded:
                await MainActor.run {
                    self.showQuotaExceeded = true
                    self.isLoading = false
                }
                
            case .upgradeRequired:
                await MainActor.run {
                    self.showQuotaExceeded = true
                    self.isLoading = false
                }
            }
            
        } catch {
            await MainActor.run {
                self.currentResponse = "Error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func submitQueryProgressive(_ query: String) async {
        // Progressive loading implementation
        await submitQuery(query)
    }
    
    func useCachedQuery(_ cached: CachedQueryResult) {
        currentResponse = cached.response
        isFromCache = true
        cacheConfidence = cached.similarity
    }
    
    func clearCache() {
        // Clear cache implementation
    }
    
    private func callPerplexityAPI(query: String, context: String) async -> String {
        // Simulated API call
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return "This is a simulated response for: \(query)\n\nContext used: \(context.prefix(100))..."
    }
}

struct CachedQueryResult: Identifiable {
    let id = UUID()
    let query: String
    let response: String
    let similarity: Double
}

#Preview {
    NavigationStack {
        OptimizedAIQueryView(book: Book(title: "Sample Book", author: "Author"))
    }
}