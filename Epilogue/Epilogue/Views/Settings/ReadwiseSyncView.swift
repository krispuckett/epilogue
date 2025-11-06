import SwiftUI
import SwiftData

struct ReadwiseSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var readwise = ReadwiseService.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    @State private var apiToken = ""
    @State private var showingTokenInput = false
    @State private var syncDirection = ReadwiseService.SyncDirection.both
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient gradient background
                AmbientChatGradientView()
                    .opacity(0.6)
                    .ignoresSafeArea()
                
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Authentication Status
                        authenticationSection
                        
                        // Sync Options
                        if readwise.isAuthenticated {
                            syncOptionsSection
                            
                            // Sync Status
                            syncStatusSection
                            
                            // Sync Button
                            syncButtonSection
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Readwise Sync")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
        .alert("Sync Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(readwise.error?.errorDescription ?? "An unknown error occurred")
        }
        .onChange(of: readwise.error) { _, newError in
            showingError = newError != nil
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryAccent,
                            themeManager.currentTheme.primaryAccent.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: readwise.isSyncing)
            
            Text("Sync your highlights and notes with Readwise")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            
            Text("Import your reading highlights from Readwise or export your Epilogue captures to build your knowledge base")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    // MARK: - Authentication Section
    private var authenticationSection: some View {
        VStack(spacing: 12) {
            // Status Card
            HStack(spacing: 16) {
                Image(systemName: readwise.isAuthenticated ? "checkmark.circle.fill" : "key.fill")
                    .font(.title2)
                    .foregroundStyle(readwise.isAuthenticated ? .green : .orange)
                    .glassEffect(in: Circle())
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(readwise.isAuthenticated ? "Connected to Readwise" : "Not Connected")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(readwise.isAuthenticated ? "Your account is linked" : "Add your API token to sync")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                if readwise.isAuthenticated {
                    Button {
                        readwise.removeToken()
                        apiToken = ""
                    } label: {
                        Text("Disconnect")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(in: Capsule())
                    }
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            
            // Add Token Button
            if !readwise.isAuthenticated {
                Button {
                    showingTokenInput = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add API Token")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(themeManager.currentTheme.primaryAccent.opacity(0.15))
                            .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        themeManager.currentTheme.primaryAccent.opacity(0.3),
                                        lineWidth: 1
                                    )
                            }
                    }
                }
                .sheet(isPresented: $showingTokenInput) {
                    TokenInputSheet(apiToken: $apiToken) { token in
                        readwise.setToken(token)
                    }
                }
                
                // Help Link
                Link(destination: URL(string: "https://readwise.io/access_token")!) {
                    HStack {
                        Text("Get your Readwise API token")
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .font(.caption)
                    .foregroundStyle(themeManager.currentTheme.primaryAccent)
                }
            }
        }
    }
    
    // MARK: - Sync Options Section
    private var syncOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SYNC OPTIONS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.5))
                .kerning(1.0)
            
            // Direction Picker
            VStack(spacing: 0) {
                ForEach([
                    (ReadwiseService.SyncDirection.both, "Two-Way Sync", "arrow.left.arrow.right"),
                    (ReadwiseService.SyncDirection.importOnly, "Import Only", "arrow.down.circle"),
                    (ReadwiseService.SyncDirection.exportOnly, "Export Only", "arrow.up.circle")
                ], id: \.0) { direction, label, icon in
                    Button {
                        syncDirection = direction
                    } label: {
                        HStack {
                            Image(systemName: icon)
                                .frame(width: 24)
                            
                            Text(label)
                                .font(.body)
                            
                            Spacer()
                            
                            if syncDirection == direction {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundStyle(themeManager.currentTheme.primaryAccent)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background {
                            if syncDirection == direction {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(themeManager.currentTheme.primaryAccent.opacity(0.1))
                            }
                        }
                    }
                    
                    if direction != ReadwiseService.SyncDirection.exportOnly {
                        Divider()
                            .background(.white.opacity(0.1))
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
    
    // MARK: - Sync Status Section
    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Last Sync
            if let lastSync = readwise.lastSyncDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    
                    Text("Last synced")
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(lastSync, style: .relative)
                        .foregroundStyle(.white)
                }
                .font(.subheadline)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.05))
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            
            // Progress
            if let progress = readwise.syncProgress {
                VStack(alignment: .leading, spacing: 8) {
                    Text(progress.message)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    ProgressView(value: Double(progress.current), total: Double(progress.total))
                        .tint(themeManager.currentTheme.primaryAccent)
                    
                    Text("\(progress.current) of \(progress.total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.05))
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
    
    // MARK: - Sync Button Section
    private var syncButtonSection: some View {
        Button {
            Task {
                await readwise.syncWithReadwise(
                    modelContext: modelContext,
                    direction: syncDirection
                )
            }
        } label: {
            HStack {
                if readwise.isSyncing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                
                Text(readwise.isSyncing ? "Syncing..." : "Sync Now")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(themeManager.currentTheme.primaryAccent.gradient)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .disabled(readwise.isSyncing)
    }
}

// MARK: - Token Input Sheet
struct TokenInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var apiToken: String
    let onSave: (String) -> Void
    
    @State private var isValidating = false
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AmbientChatGradientView()
                    .opacity(0.4)
                    .ignoresSafeArea()
                
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Instructions
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.largeTitle)
                            .foregroundStyle(themeManager.currentTheme.primaryAccent)
                        
                        Text("Enter your Readwise API token")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("You can find this in your Readwise account settings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Token Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Token")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("readwise_token_xxxxx", text: $apiToken)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.05))
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                    }
                    
                    Spacer()
                    
                    // Save Button
                    Button {
                        onSave(apiToken)
                        dismiss()
                    } label: {
                        Text("Save Token")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(themeManager.currentTheme.primaryAccent.gradient)
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                    }
                    .disabled(apiToken.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Add API Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// Preview
#Preview {
    ReadwiseSyncView()
        .preferredColorScheme(.dark)
}