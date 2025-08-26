import SwiftUI

struct PerplexitySettingsView: View {
    @AppStorage("perplexity_api_key") private var apiKey = ""
    @AppStorage("isProUser") private var isPro = false
    @AppStorage("gandalfMode") private var gandalfMode = false
    @AppStorage("preferredModel") private var preferredModel = "sonar-small-chat"
    @AppStorage("enableStreaming") private var enableStreaming = true
    @AppStorage("cacheResponses") private var cacheResponses = true
    @AppStorage("maxTokensPerRequest") private var maxTokensPerRequest = 1000
    
    @State private var showingAPIKeyInput = false
    @State private var tempAPIKey = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var showingUpgradeView = false
    
    @StateObject private var usageStats = UsageStatsViewModel()
    
    enum ConnectionTestResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // API Configuration
                Section("API Configuration") {
                    HStack {
                        Text("API Key")
                        Spacer()
                        if apiKey.isEmpty {
                            Text("Not Set")
                                .foregroundColor(.secondary)
                        } else {
                            Text("••••••\(String(apiKey.suffix(4)))")
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        tempAPIKey = apiKey
                        showingAPIKeyInput = true
                    }
                    
                    if !apiKey.isEmpty {
                        Button(action: testConnection) {
                            HStack {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text("Test Connection")
                            }
                        }
                        .disabled(isTestingConnection)
                        
                        if let result = connectionTestResult {
                            switch result {
                            case .success:
                                Label("Connected", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            case .failure(let error):
                                Label(error, systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // Subscription Status
                Section("Subscription") {
                    HStack {
                        Label("Status", systemImage: isPro ? "crown.fill" : "person.circle")
                        Spacer()
                        Text(isPro ? "Pro" : "Free")
                            .foregroundColor(isPro ? .purple : .secondary)
                    }
                    
                    if !isPro {
                        Button(action: { showingUpgradeView = true }) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Upgrade to Pro")
                                Spacer()
                                Text("$9.99/mo")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.purple)
                    }
                }
                
                // Model Selection
                Section("Model Settings") {
                    Picker("Default Model", selection: $preferredModel) {
                        Text("Sonar Small (Free)").tag("sonar-small-chat")
                        if isPro {
                            Text("Sonar Medium (Pro)").tag("sonar-medium-chat")
                            Text("Sonar Small Online").tag("sonar-small-online")
                            Text("Sonar Medium Online").tag("sonar-medium-online")
                        }
                    }
                    
                    Stepper("Max Tokens: \(maxTokensPerRequest)", value: $maxTokensPerRequest, in: 100...4000, step: 100)
                    
                    Toggle("Enable Streaming", isOn: $enableStreaming)
                    Toggle("Cache Responses", isOn: $cacheResponses)
                }
                
                // Developer Options
                Section("Developer Options") {
                    Toggle(isOn: $gandalfMode) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text("Gandalf Mode")
                                    .foregroundColor(.purple)
                                Text("Unlimited testing (no quota limits)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onChange(of: gandalfMode) { _, enabled in
                        Task {
                            await SonarRequestManager.shared.enableGandalf(enabled)
                        }
                    }
                    
                    if gandalfMode {
                        Label("Testing mode active - quotas disabled", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Usage Statistics
                Section("Usage Statistics") {
                    HStack {
                        Label("Today's Queries", systemImage: "chart.bar")
                        Spacer()
                        if gandalfMode {
                            Text("∞")
                                .foregroundColor(.purple)
                        } else {
                            Text("\(usageStats.queriesUsedToday)/\(usageStats.dailyQuota)")
                                .foregroundColor(usageStats.queriesUsedToday >= usageStats.dailyQuota ? .red : .primary)
                        }
                    }
                    
                    HStack {
                        Label("Tokens Used", systemImage: "bolt")
                        Spacer()
                        Text("\(usageStats.tokensUsedToday)")
                    }
                    
                    HStack {
                        Label("Estimated Cost", systemImage: "dollarsign.circle")
                        Spacer()
                        Text(String(format: "$%.4f", usageStats.estimatedCostToday))
                    }
                    
                    HStack {
                        Label("Cache Hit Rate", systemImage: "speedometer")
                        Spacer()
                        Text("\(Int(usageStats.cacheHitRate * 100))%")
                            .foregroundColor(usageStats.cacheHitRate > 0.3 ? .green : .orange)
                    }
                    
                    Button("View Detailed Analytics") {
                        // Navigate to analytics
                    }
                }
                
                // Cache Management
                Section("Cache Management") {
                    HStack {
                        Label("Cached Responses", systemImage: "archivebox")
                        Spacer()
                        Text("\(usageStats.cachedResponseCount)")
                    }
                    
                    Button(action: clearCache) {
                        Label("Clear Cache", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    
                    Button("Export Cache") {
                        // Export cache
                    }
                }
                
                // Network Settings
                Section("Network") {
                    Toggle("Auto-retry Failed Requests", isOn: .constant(true))
                    Toggle("Process Offline Queue on Connect", isOn: .constant(true))
                    
                    if usageStats.offlineQueueCount > 0 {
                        Button("Process \(usageStats.offlineQueueCount) Offline Requests") {
                            Task {
                                await SonarRequestManager.shared.processOfflineQueue()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Perplexity Settings")
            .sheet(isPresented: $showingAPIKeyInput) {
                APIKeyInputView(apiKey: $tempAPIKey) { key in
                    apiKey = key
                    KeychainHelper.shared.setAPIKey(key)
                    Task {
                        await SonarRequestManager.shared.configure(apiKey: key, isPro: isPro)
                    }
                    showingAPIKeyInput = false
                }
            }
            .sheet(isPresented: $showingUpgradeView) {
                ProUpgradeView()
            }
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            do {
                // Test with a simple query
                let testMessages = [
                    ChatMessage(role: .user, content: "Test connection")
                ]
                
                _ = try await SonarRequestManager.shared.submitRequest(
                    messages: testMessages,
                    useCache: false
                )
                
                await MainActor.run {
                    connectionTestResult = .success
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(error.localizedDescription)
                    isTestingConnection = false
                }
            }
        }
    }
    
    private func clearCache() {
        // Clear cache implementation
        usageStats.cachedResponseCount = 0
    }
}

// MARK: - API Key Input View

struct APIKeyInputView: View {
    @Binding var apiKey: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Enter your Perplexity API Key")
                    .font(.headline)
                
                Text("You can find your API key at https://perplexity.ai/settings/api")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Your API key is stored securely in the iOS Keychain")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(apiKey)
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
        }
    }
}

// MARK: - Pro Upgrade View

struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessingPurchase = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Upgrade to Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Unlock the full power of AI assistance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        ProFeatureRow(
                            icon: "infinity",
                            title: "Unlimited Queries",
                            description: "No daily limits"
                        )
                        
                        ProFeatureRow(
                            icon: "cpu",
                            title: "Advanced Models",
                            description: "Access to Sonar Medium models"
                        )
                        
                        ProFeatureRow(
                            icon: "bolt.fill",
                            title: "Priority Processing",
                            description: "Faster response times"
                        )
                        
                        ProFeatureRow(
                            icon: "doc.text.magnifyingglass",
                            title: "Extended Context",
                            description: "4x longer context windows"
                        )
                        
                        ProFeatureRow(
                            icon: "square.and.arrow.down",
                            title: "Export & Analytics",
                            description: "Advanced analytics and export options"
                        )
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(16)
                    
                    // Pricing
                    VStack(spacing: 8) {
                        Text("$9.99")
                            .font(.system(size: 48, weight: .bold))
                        
                        Text("per month")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Cancel anytime")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                    
                    // Purchase button
                    Button(action: purchasePro) {
                        if isProcessingPurchase {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Subscribe Now")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .disabled(isProcessingPurchase)
                    
                    Button("Restore Purchase") {
                        // Restore purchase
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func purchasePro() {
        isProcessingPurchase = true
        // Implement IAP
    }
}

struct ProFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Usage Stats View Model

class UsageStatsViewModel: ObservableObject {
    @Published var queriesUsedToday = 0
    @Published var dailyQuota = 20
    @Published var tokensUsedToday = 0
    @Published var estimatedCostToday = 0.0
    @Published var cacheHitRate = 0.0
    @Published var cachedResponseCount = 0
    @Published var offlineQueueCount = 0
    
    init() {
        loadStats()
    }
    
    func loadStats() {
        Task {
            let manager = SonarRequestManager.shared
            let usage = await manager.getDailyUsage()
            
            await MainActor.run {
                self.queriesUsedToday = usage.queries
                self.tokensUsedToday = usage.tokens
                self.estimatedCostToday = usage.cost
            }
        }
    }
}

#Preview {
    PerplexitySettingsView()
}