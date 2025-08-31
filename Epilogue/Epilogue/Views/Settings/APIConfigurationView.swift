import SwiftUI

struct APIConfigurationView: View {
    @State private var apiKey: String = ""
    @State private var showingAPIKey = false
    @State private var showingSaveConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasExistingKey = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text("Perplexity API Key")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.orange)
                        }
                        
                        if hasExistingKey {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("API Key Configured")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        SecureInputField(
                            text: $apiKey,
                            isRevealed: $showingAPIKey,
                            placeholder: hasExistingKey ? "Enter new API key" : "pplx-..."
                        )
                        
                        Text("Your API key is stored securely in the iOS Keychain")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("API Configuration")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Get your API key from:")
                        Link("perplexity.ai/settings/api", 
                             destination: URL(string: "https://www.perplexity.ai/settings/api")!)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button {
                        saveAPIKey()
                    } label: {
                        HStack {
                            Spacer()
                            Text(hasExistingKey ? "Update API Key" : "Save API Key")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .disabled(apiKey.isEmpty)
                    .sensoryFeedback(.impact, trigger: showingSaveConfirmation)
                    
                    if hasExistingKey {
                        Button(role: .destructive) {
                            removeAPIKey()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Remove API Key")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                    }
                }
                
                Section {
                    DisclosureGroup("Security Information") {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(
                                icon: "lock.shield.fill",
                                title: "Secure Storage",
                                description: "Your API key is encrypted and stored in the iOS Keychain"
                            )
                            
                            InfoRow(
                                icon: "network.badge.shield.half.filled",
                                title: "Secure Transmission",
                                description: "All API requests use HTTPS encryption"
                            )
                            
                            InfoRow(
                                icon: "hand.raised.fill",
                                title: "Never Shared",
                                description: "Your API key never leaves your device except for API calls"
                            )
                            
                            InfoRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Key Rotation",
                                description: "Rotate your key regularly for best security"
                            )
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("API Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by parent
                    }
                }
            }
            .alert("API Key Saved", isPresented: $showingSaveConfirmation) {
                Button("OK") { }
            } message: {
                Text("Your API key has been securely stored")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                checkExistingKey()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func checkExistingKey() {
        hasExistingKey = KeychainManager.shared.hasPerplexityAPIKey
        // Don't load the actual key for security
    }
    
    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            errorMessage = "Please enter an API key"
            showingError = true
            return
        }
        
        guard trimmedKey.hasPrefix("pplx-") else {
            errorMessage = "Invalid API key format. Keys should start with 'pplx-'"
            showingError = true
            return
        }
        
        do {
            try KeychainManager.shared.configurePerplexityAPIKey(trimmedKey)
            
            // API key saved to Keychain
            // Services will read it from there when needed
            
            // Clear the input field for security
            apiKey = ""
            hasExistingKey = true
            showingSaveConfirmation = true
            
            SensoryFeedback.success()
        } catch {
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
            showingError = true
            HapticManager.shared.error()
        }
    }
    
    private func removeAPIKey() {
        do {
            try KeychainManager.shared.deletePerplexityAPIKey()
            hasExistingKey = false
            apiKey = ""
            SensoryFeedback.success()
        } catch {
            errorMessage = "Failed to remove API key: \(error.localizedDescription)"
            showingError = true
            HapticManager.shared.error()
        }
    }
}

// MARK: - Supporting Views

struct SecureInputField: View {
    @Binding var text: String
    @Binding var isRevealed: Bool
    let placeholder: String
    
    var body: some View {
        HStack {
            Group {
                if isRevealed {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                } else {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    APIConfigurationView()
        .preferredColorScheme(.dark)
}