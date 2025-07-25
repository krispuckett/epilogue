import SwiftUI
import Combine

struct WhisperModelManagerView: View {
    @StateObject private var whisperProcessor = WhisperProcessor()
    @State private var showingDeleteConfirmation = false
    @State private var modelToDelete: WhisperKitModel?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    
                    Text("Whisper Models")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                    
                    Text("High-quality speech recognition models")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                // Current Model Status
                if let currentModel = whisperProcessor.currentModel {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Active Model")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            
                            Text(currentModel.displayName)
                                .font(.system(size: 18, weight: .medium))
                            
                            Spacer()
                            
                            Text("\(currentModel.sizeInMB) MB")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.green.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                }
                
                // Model List
                VStack(spacing: 16) {
                    HStack {
                        Text("Available Models")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    ForEach(WhisperKitModel.allCases, id: \.self) { model in
                        ModelRowView(
                            model: model,
                            whisperProcessor: whisperProcessor,
                            onDelete: {
                                modelToDelete = model
                                showingDeleteConfirmation = true
                            }
                        )
                    }
                }
                
                // Info Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("About Whisper Models")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(
                            icon: "speedometer",
                            title: "Tiny",
                            description: "Fastest processing, good for real-time use"
                        )
                        
                        InfoRow(
                            icon: "slider.horizontal.3",
                            title: "Base",
                            description: "Balanced speed and accuracy"
                        )
                        
                        InfoRow(
                            icon: "star.circle",
                            title: "Small",
                            description: "Best accuracy, slower processing"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.black.opacity(0.05))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .alert("Delete Model", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    whisperProcessor.deleteModel(model)
                }
            }
        } message: {
            Text("Are you sure you want to delete the \(modelToDelete?.displayName ?? "") model? You can download it again later.")
        }
    }
}

struct ModelRowView: View {
    let model: WhisperKitModel
    @ObservedObject var whisperProcessor: WhisperProcessor
    let onDelete: () -> Void
    
    private var isDownloaded: Bool {
        whisperProcessor.availableModels.contains(model)
    }
    
    private var isDownloading: Bool {
        whisperProcessor.isDownloading && whisperProcessor.currentModel == model
    }
    
    private var downloadProgress: Double {
        whisperProcessor.downloadProgress
    }
    
    private var isCurrentModel: Bool {
        whisperProcessor.currentModel == model && whisperProcessor.isModelLoaded
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Model Icon
                ZStack {
                    Circle()
                        .fill(isCurrentModel ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isDownloaded ? "waveform.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isCurrentModel ? Color(red: 1.0, green: 0.55, blue: 0.26) : .secondary)
                }
                
                // Model Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(model.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Action Button
                if isDownloading {
                    Button {
                        // Cancel download - not implemented in WhisperKit yet
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .disabled(true)
                } else if isDownloaded {
                    Menu {
                        if !isCurrentModel {
                            Button {
                                Task {
                                    try? await whisperProcessor.loadModel(model)
                                }
                            } label: {
                                Label("Use This Model", systemImage: "checkmark.circle")
                            }
                        }
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete Model", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        Task {
                            try? await whisperProcessor.loadModel(model)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12))
                            Text("Download")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26))
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // Download Progress
            if isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
                    
                    Text("\(Int(downloadProgress * 100))% • \(Int(Double(model.sizeInMB) * downloadProgress)) / \(model.sizeInMB) MB")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentModel ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

struct WhisperModelManagerView_Previews: PreviewProvider {
    static var previews: some View {
        WhisperModelManagerView()
    }
}