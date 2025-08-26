import SwiftUI
import Charts
import CoreData

struct QueryAnalyticsDashboard: View {
    @StateObject private var viewModel = AnalyticsDashboardViewModel()
    @State private var selectedTimeRange: TimeRange = .today
    @State private var showingExportOptions = false
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Selector
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Key Metrics
                    KeyMetricsView(metrics: viewModel.keyMetrics)
                    
                    // Cache Performance Chart
                    CachePerformanceChart(data: viewModel.performanceData)
                    
                    // Query Type Distribution
                    QueryTypeDistribution(distribution: viewModel.queryTypeDistribution)
                    
                    // Cost Analysis
                    CostAnalysisView(costData: viewModel.costAnalysis)
                    
                    // Recent Cache Hits
                    RecentCacheHitsView(cacheHits: viewModel.recentCacheHits)
                    
                    // Optimization Suggestions
                    OptimizationSuggestionsView(suggestions: viewModel.suggestions)
                }
                .padding(.bottom)
            }
            .navigationTitle("Query Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingExportOptions = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportAnalyticsView(analytics: viewModel.exportData())
            }
            .onAppear {
                viewModel.loadAnalytics(for: selectedTimeRange)
            }
            .onChange(of: selectedTimeRange) { _, newValue in
                viewModel.loadAnalytics(for: newValue)
            }
        }
    }
}

// MARK: - Key Metrics View

struct KeyMetricsView: View {
    let metrics: KeyMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    MetricCard(
                        title: "Cache Hit Rate",
                        value: "\(Int(metrics.cacheHitRate * 100))%",
                        subtitle: "\(metrics.cacheHits) hits",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    MetricCard(
                        title: "Avg Response Time",
                        value: String(format: "%.2fs", metrics.averageResponseTime),
                        subtitle: "per query",
                        icon: "timer",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Tokens Saved",
                        value: "\(metrics.tokensSaved)",
                        subtitle: "from cache",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .orange
                    )
                    
                    MetricCard(
                        title: "Cost Saved",
                        value: String(format: "$%.2f", metrics.costSaved),
                        subtitle: "this period",
                        icon: "dollarsign.circle.fill",
                        color: .purple
                    )
                    
                    MetricCard(
                        title: "Total Queries",
                        value: "\(metrics.totalQueries)",
                        subtitle: "\(metrics.uniqueQueries) unique",
                        icon: "magnifyingglass",
                        color: .indigo
                    )
                }
                .padding(.horizontal)
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 150)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Cache Performance Chart

struct CachePerformanceChart: View {
    let data: [PerformanceDataPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache Performance")
                .font(.headline)
                .padding(.horizontal)
            
            Chart(data) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Hit Rate", point.hitRate)
                )
                .foregroundStyle(.green)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Hit Rate", point.hitRate)
                )
                .foregroundStyle(.linearGradient(
                    colors: [.green.opacity(0.3), .green.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
    }
}

// MARK: - Query Type Distribution

struct QueryTypeDistribution: View {
    let distribution: [QueryTypeData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Query Types")
                .font(.headline)
                .padding(.horizontal)
            
            Chart(distribution) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("Type", item.type))
                .cornerRadius(4)
            }
            .frame(height: 250)
            .padding(.horizontal)
            
            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(distribution) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10, height: 10)
                        Text(item.type)
                            .font(.caption)
                        Spacer()
                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Cost Analysis

struct CostAnalysisView: View {
    let costData: CostAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Analysis")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Without Cache")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "$%.2f", costData.withoutCache))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading) {
                    Text("With Cache")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "$%.2f", costData.withCache))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "$%.2f", costData.saved))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("\(Int(costData.savingsPercentage))%")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// MARK: - Recent Cache Hits

struct RecentCacheHitsView: View {
    let cacheHits: [CacheHitInfo]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Cache Hits")
                    .font(.headline)
                Spacer()
                Text("\(cacheHits.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cacheHits.prefix(5)) { hit in
                        CacheHitCard(hit: hit)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct CacheHitCard: View {
    let hit: CacheHitInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hit.query)
                .font(.caption)
                .lineLimit(2)
            
            HStack {
                Label("\(hit.tokensSaved)", systemImage: "bolt.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Text(hit.confidence, format: .percent)
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            
            Text(hit.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 200)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Optimization Suggestions

struct OptimizationSuggestionsView: View {
    let suggestions: [OptimizationSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimization Suggestions")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(suggestions) { suggestion in
                HStack(spacing: 12) {
                    Image(systemName: suggestion.icon)
                        .foregroundColor(suggestion.priority.color)
                        .font(.title2)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(suggestion.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let impact = suggestion.estimatedImpact {
                            Text(impact)
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    if suggestion.isActionable {
                        Button("Apply") {
                            suggestion.action?()
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - View Model

class AnalyticsDashboardViewModel: ObservableObject {
    @Published var keyMetrics = KeyMetrics()
    @Published var performanceData: [PerformanceDataPoint] = []
    @Published var queryTypeDistribution: [QueryTypeData] = []
    @Published var costAnalysis = CostAnalysis()
    @Published var recentCacheHits: [CacheHitInfo] = []
    @Published var suggestions: [OptimizationSuggestion] = []
    
    private let coreDataManager = CoreDataManager.shared
    
    func loadAnalytics(for timeRange: QueryAnalyticsDashboard.TimeRange) {
        let dateRange = getDateRange(for: timeRange)
        let analytics = coreDataManager.getAnalytics(for: dateRange)
        
        processAnalytics(analytics)
        generateSuggestions()
    }
    
    private func getDateRange(for timeRange: QueryAnalyticsDashboard.TimeRange) -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeRange {
        case .today:
            let start = calendar.startOfDay(for: now)
            return DateInterval(start: start, end: now)
            
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return DateInterval(start: start, end: now)
            
        case .month:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return DateInterval(start: start, end: now)
            
        case .all:
            let start = Date.distantPast
            return DateInterval(start: start, end: now)
        }
    }
    
    private func processAnalytics(_ analytics: [QueryAnalytics]) {
        guard !analytics.isEmpty else { return }
        
        // Calculate key metrics
        let totalQueries = analytics.reduce(0) { $0 + Int($1.totalQueries) }
        let cacheHits = analytics.reduce(0) { $0 + Int($1.cacheHits) }
        let totalTokens = analytics.reduce(0) { $0 + Int($1.totalTokensUsed) }
        let totalCost = analytics.reduce(0.0) { $0 + $1.totalCost }
        
        keyMetrics.totalQueries = totalQueries
        keyMetrics.cacheHits = cacheHits
        keyMetrics.cacheHitRate = totalQueries > 0 ? Double(cacheHits) / Double(totalQueries) : 0
        keyMetrics.tokensSaved = Int(Double(totalTokens) * keyMetrics.cacheHitRate)
        keyMetrics.costSaved = totalCost * keyMetrics.cacheHitRate
        keyMetrics.averageResponseTime = analytics.reduce(0.0) { $0 + $1.averageResponseTime } / Double(analytics.count)
        
        // Generate performance data
        performanceData = analytics.map { analytics in
            PerformanceDataPoint(
                date: analytics.date ?? Date(),
                hitRate: analytics.cacheHitRate,
                queries: Int(analytics.totalQueries)
            )
        }
        
        // Cost analysis
        costAnalysis.withoutCache = totalCost / (1 - keyMetrics.cacheHitRate)
        costAnalysis.withCache = totalCost
        costAnalysis.saved = costAnalysis.withoutCache - costAnalysis.withCache
        costAnalysis.savingsPercentage = costAnalysis.saved / costAnalysis.withoutCache * 100
    }
    
    private func generateSuggestions() {
        suggestions = []
        
        // Cache hit rate suggestion
        if keyMetrics.cacheHitRate < 0.3 {
            suggestions.append(OptimizationSuggestion(
                title: "Low Cache Hit Rate",
                description: "Your cache hit rate is below 30%. Consider enabling semantic matching for better cache utilization.",
                priority: .high,
                estimatedImpact: "Could save up to 50% more on API costs",
                isActionable: true
            ))
        }
        
        // Token usage suggestion
        if keyMetrics.averageResponseTime > 5 {
            suggestions.append(OptimizationSuggestion(
                title: "Optimize Context Windows",
                description: "Response times are high. Try reducing context window size for simpler queries.",
                priority: .medium,
                estimatedImpact: "Reduce response time by 30%",
                isActionable: true
            ))
        }
        
        // Cache cleanup suggestion
        let cacheSize = coreDataManager.getCacheSize()
        if cacheSize > 1000 {
            suggestions.append(OptimizationSuggestion(
                title: "Cache Cleanup Recommended",
                description: "You have over 1000 cached queries. Consider cleaning up old entries.",
                priority: .low,
                estimatedImpact: "Free up storage space",
                isActionable: true,
                action: {
                    self.coreDataManager.cleanupOldCache()
                }
            ))
        }
    }
    
    func exportData() -> Data? {
        return coreDataManager.exportCache()
    }
}

// MARK: - Supporting Types

struct KeyMetrics {
    var cacheHitRate: Double = 0
    var averageResponseTime: Double = 0
    var tokensSaved: Int = 0
    var costSaved: Double = 0
    var totalQueries: Int = 0
    var uniqueQueries: Int = 0
    var cacheHits: Int = 0
}

struct PerformanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let hitRate: Double
    let queries: Int
}

struct QueryTypeData: Identifiable {
    let id = UUID()
    let type: String
    let count: Int
    let color: Color
}

struct CostAnalysis {
    var withoutCache: Double = 0
    var withCache: Double = 0
    var saved: Double = 0
    var savingsPercentage: Double = 0
}

struct CacheHitInfo: Identifiable {
    let id = UUID()
    let query: String
    let tokensSaved: Int
    let confidence: Double
    let timestamp: Date
}

struct OptimizationSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let priority: Priority
    let estimatedImpact: String?
    let isActionable: Bool
    var action: (() -> Void)? = nil
    
    enum Priority {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }
    }
    
    var icon: String {
        switch priority {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "lightbulb.fill"
        case .low: return "info.circle.fill"
        }
    }
}

#Preview {
    QueryAnalyticsDashboard()
}