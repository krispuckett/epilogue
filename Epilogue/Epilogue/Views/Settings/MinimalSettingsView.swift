import SwiftUI
import SwiftData

// MARK: - Minimal Settings View
struct MinimalSettingsView: View {
    @AppStorage("aiProvider") private var aiProvider = "apple"
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("enableDataSync") private var enableDataSync = false
    @AppStorage("processOnDevice") private var processOnDevice = true
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingAbout = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle gradient background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - AI Settings
                        settingsSection(title: "Intelligence") {
                            // AI Provider
                            HStack {
                                Label("AI Provider", systemImage: "brain")
                                    .foregroundStyle(.white.opacity(0.9))
                                Spacer()
                                Picker("", selection: $aiProvider) {
                                    Text("Apple").tag("apple")
                                    Text("Perplexity").tag("perplexity")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 150)
                            }
                            .padding(.vertical, 12)
                            
                            // On-Device Processing
                            Toggle(isOn: $processOnDevice) {
                                Label("Process On-Device", systemImage: "lock.shield")
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .tint(.blue)
                            .padding(.vertical, 12)
                        }
                        
                        // MARK: - Experience
                        settingsSection(title: "Experience") {
                            // Animations
                            Toggle(isOn: $enableAnimations) {
                                Label("Animations", systemImage: "sparkles")
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .tint(.blue)
                            .padding(.vertical, 12)
                        }
                        
                        // MARK: - Data
                        settingsSection(title: "Data") {
                            // Sync
                            Toggle(isOn: $enableDataSync) {
                                Label("iCloud Sync", systemImage: "icloud")
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .tint(.blue)
                            .padding(.vertical, 12)
                            
                            // Export
                            Button {
                                exportData()
                            } label: {
                                HStack {
                                    Label("Export Library", systemImage: "square.and.arrow.up")
                                        .foregroundStyle(.white.opacity(0.9))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                .padding(.vertical, 12)
                            }
                        }
                        
                        // MARK: - About
                        Button {
                            showingAbout = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white.opacity(0.6))
                                
                                Text("Epilogue")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                
                                Text("Version \(appVersion)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        
                        // Footer
                        Text("Made with ❤️ in San Francisco")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.top, 12)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    // MARK: - Settings Section
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .padding(.bottom, 12)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Export Data
    private func exportData() {
        // Export implementation
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // App Icon
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 40)
                        
                        // App Info
                        VStack(spacing: 8) {
                            Text("Epilogue")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text("Your Reading Companion")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        // Features
                        VStack(alignment: .leading, spacing: 16) {
                            FeatureRow(icon: "sparkles", title: "AI-Powered", description: "Smart book insights and recommendations")
                            FeatureRow(icon: "quote.bubble", title: "Capture Quotes", description: "Save and organize your favorite passages")
                            FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Track Progress", description: "Monitor your reading habits")
                            FeatureRow(icon: "books.vertical", title: "Beautiful Library", description: "Organize your collection with style")
                        }
                        .padding(.horizontal, 24)
                        
                        // Credits
                        VStack(spacing: 12) {
                            Text("Created by")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text("Your Name")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 20)
                        
                        // Links
                        HStack(spacing: 32) {
                            Link(destination: URL(string: "https://epilogue.app")!) {
                                Label("Website", systemImage: "globe")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                            }
                            
                            Link(destination: URL(string: "mailto:support@epilogue.app")!) {
                                Label("Support", systemImage: "envelope")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}