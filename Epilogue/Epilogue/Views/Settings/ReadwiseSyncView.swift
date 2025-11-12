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
                    VStack(spacing: 28) {
                        // Header
                        headerSection
                        
                        // Main content with consistent spacing
                        VStack(spacing: 20) {
                            // Authentication Status
                            authenticationSection
                            
                            // Sync Options
                            if readwise.isAuthenticated {
                                syncOptionsSection
                                
                                // Sync Status
                                if readwise.lastSyncDate != nil || readwise.syncProgress != nil {
                                    syncStatusSection
                                }
                                
                                // Sync Button
                                syncButtonSection
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top, 12)
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
        VStack(alignment: .leading, spacing: 20) {
            // Subtle icon row with gradient
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(themeManager.currentTheme.primaryAccent)
                    .symbolEffect(.pulse, value: readwise.isSyncing)
                
                Text("Readwise Integration")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(themeManager.currentTheme.primaryAccent.opacity(0.08))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            // Description text - left aligned, more subtle
            VStack(alignment: .leading, spacing: 12) {
                Text("Connect your reading ecosystem")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("Import highlights from your Readwise library or export Epilogue captures to build your personal knowledge graph.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Authentication Section
    private var authenticationSection: some View {
        VStack(spacing: 16) {
            // Status Card - more refined
            HStack(spacing: 16) {
                // Cleaner icon without extra glass effect
                ZStack {
                    Circle()
                        .fill(readwise.isAuthenticated ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: readwise.isAuthenticated ? "checkmark.circle.fill" : "key.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(readwise.isAuthenticated ? .green : .orange)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(readwise.isAuthenticated ? "Connected" : "Not Connected")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(readwise.isAuthenticated ? "Syncing enabled" : "Add API token to start")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                if readwise.isAuthenticated {
                    Button {
                        readwise.removeToken()
                        apiToken = ""
                    } label: {
                        Text("Disconnect")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                Capsule()
                                    .fill(.white.opacity(0.1))
                                    .glassEffect(in: Capsule())
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.04))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    }
            }
            
            // Add Token Button
            if !readwise.isAuthenticated {
                VStack(spacing: 12) {
                    Button {
                        showingTokenInput = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Add API Token")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(themeManager.currentTheme.primaryAccent.opacity(0.2))
                                .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            themeManager.currentTheme.primaryAccent.opacity(0.4),
                                            lineWidth: 0.5
                                        )
                                }
                        }
                    }
                    .sheet(isPresented: $showingTokenInput) {
                        TokenInputSheet(apiToken: $apiToken) { token in
                            readwise.setToken(token)
                        }
                    }
                    
                    // Help Link - more subtle
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Don't have a Readwise account?")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Link(destination: URL(string: "https://readwise.io/i/kris")!) {
                            HStack(spacing: 8) {
                                Text("Try Readwise free for 30 days")
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(themeManager.currentTheme.primaryAccent.opacity(0.8))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Sync Options Section
    private var syncOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Direction")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            
            // Direction Picker with segmented style
            VStack(spacing: 1) {
                ForEach([
                    (ReadwiseService.SyncDirection.both, "Two-Way Sync", "arrow.left.arrow.right"),
                    (ReadwiseService.SyncDirection.importOnly, "Import Only", "arrow.down.circle"),
                    (ReadwiseService.SyncDirection.exportOnly, "Export Only", "arrow.up.circle")
                ], id: \.0) { direction, label, icon in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            syncDirection = direction
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .frame(width: 20)
                            
                            Text(label)
                                .font(.system(size: 15, weight: .medium))
                            
                            Spacer()
                            
                            if syncDirection == direction {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(themeManager.currentTheme.primaryAccent)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .foregroundStyle(syncDirection == direction ? .white : .white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background {
                            if syncDirection == direction {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(themeManager.currentTheme.primaryAccent.opacity(0.12))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.04))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
    
    // MARK: - Sync Status Section
    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("Sync Activity")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            
            VStack(spacing: 12) {
                // Last Sync
                if let lastSync = readwise.lastSyncDate {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last synced")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Text(lastSync, style: .relative)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.04))
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                            }
                    }
                }
                
                // Progress
                if let progress = readwise.syncProgress {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.currentTheme.primaryAccent)
                                .symbolEffect(.rotate, value: readwise.isSyncing)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(progress.message)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                
                                HStack(spacing: 8) {
                                    ProgressView(value: Double(progress.current), total: Double(progress.total))
                                        .tint(themeManager.currentTheme.primaryAccent)
                                        .scaleEffect(x: 1, y: 0.7, anchor: .leading)
                                    
                                    Text("\(progress.current)/\(progress.total)")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(themeManager.currentTheme.primaryAccent.opacity(0.06))
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(themeManager.currentTheme.primaryAccent.opacity(0.15), lineWidth: 0.5)
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Sync Button Section
    private var syncButtonSection: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    await readwise.syncWithReadwise(
                        modelContext: modelContext,
                        direction: syncDirection
                    )
                }
            } label: {
                HStack(spacing: 12) {
                    if readwise.isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 17, weight: .medium))
                    }
                    
                    Text(readwise.isSyncing ? "Syncing..." : "Sync Now")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Spacer()
                    
                    // Subtle activity indicator
                    if !readwise.isSyncing {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryAccent.opacity(readwise.isSyncing ? 0.6 : 0.8),
                                    themeManager.currentTheme.primaryAccent.opacity(readwise.isSyncing ? 0.5 : 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    themeManager.currentTheme.primaryAccent.opacity(0.3),
                                    lineWidth: 0.5
                                )
                        }
                }
            }
            .disabled(readwise.isSyncing)
            .scaleEffect(readwise.isSyncing ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: readwise.isSyncing)
            
            // Helpful context below button
            if !readwise.isSyncing && readwise.lastSyncDate == nil {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text("First sync may take a few moments")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
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
                
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section - simplified
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(themeManager.currentTheme.primaryAccent)
                            
                            Text("Add Readwise API Token")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        
                        Text("Connect your Readwise account to sync highlights between Epilogue and your reading apps")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)
                    
                    // Token Input Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("API TOKEN")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(0.5)
                        
                        TextField("Enter your token", text: $apiToken)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.04))
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                                    }
                            }
                            .overlay(alignment: .trailing) {
                                if !apiToken.isEmpty {
                                    Button {
                                        apiToken = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white.opacity(0.3))
                                            .padding(.trailing, 14)
                                    }
                                }
                            }
                        
                        // Help Link
                        Link(destination: URL(string: "https://readwise.io/access_token")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                Text("Find your token at readwise.io/access_token")
                                    .font(.system(size: 13))
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(themeManager.currentTheme.primaryAccent.opacity(0.8))
                        }
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            onSave(apiToken)
                            dismiss()
                        } label: {
                            Text("Add Token")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(themeManager.currentTheme.primaryAccent.opacity(apiToken.isEmpty ? 0.3 : 0.8))
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                        }
                        .disabled(apiToken.isEmpty)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
        .presentationCornerRadius(24)
    }
}

// Preview
#Preview {
    ReadwiseSyncView()
        .preferredColorScheme(.dark)
}