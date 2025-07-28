import SwiftUI

struct AISettingsView: View {
    @StateObject private var aiService = AICompanionService.shared
    @State private var showingAPIKeyInstructions = false
    
    var body: some View {
        List {
            Section {
                ForEach(AICompanionService.AIProvider.allCases, id: \.self) { provider in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.rawValue)
                                .font(.system(size: 16, weight: .medium))
                            
                            if !provider.isAvailable {
                                Text("Coming soon")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            } else if provider.requiresAPIKey && provider == aiService.currentProvider && !aiService.isConfigured() {
                                Text("API key required")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        Spacer()
                        
                        if provider.isAvailable {
                            Image(systemName: aiService.currentProvider == provider ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(aiService.currentProvider == provider ? .blue : .secondary)
                                .font(.system(size: 20))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if provider.isAvailable {
                            aiService.setProvider(provider)
                        }
                    }
                    .disabled(!provider.isAvailable)
                }
            } header: {
                Text("AI Provider")
            } footer: {
                if aiService.currentProvider.requiresAPIKey {
                    Button {
                        showingAPIKeyInstructions = true
                    } label: {
                        Text("How to configure API key")
                            .font(.system(size: 14))
                    }
                }
            }
            
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    if aiService.isConfigured() {
                        Label("Configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                    } else {
                        Label("Not configured", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                    }
                }
            }
        }
        .navigationTitle("AI Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAPIKeyInstructions) {
            APIKeyInstructionsView()
        }
    }
}

struct APIKeyInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Configuring Perplexity API Key")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.bottom, 10)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("1. Get your API key")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Visit perplexity.ai/settings/api to generate an API key")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.blue)
                        }
                        
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("2. Open Info.plist")
                                    .font(.system(size: 16, weight: .medium))
                                Text("In Xcode, find and open your Info.plist file")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.blue)
                        }
                        
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("3. Add the key")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Add a new row with key: PERPLEXITY_API_KEY")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("4. Paste your API key")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Set the value to your actual API key")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.on.clipboard.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Text("Security Note")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.top, 10)
                    
                    Text("Your API key is stored locally in your app and is never shared. Make sure to keep it secure and don't commit it to version control.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        AISettingsView()
    }
}