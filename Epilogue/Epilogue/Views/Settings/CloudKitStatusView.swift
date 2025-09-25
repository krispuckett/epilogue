import SwiftUI
import CloudKit
import Combine

struct CloudKitStatusView: View {
    @State private var accountStatus: CKAccountStatus?
    @State private var isChecking = true
    @State private var syncStatus: SyncStatus = .checking
    @AppStorage("isUsingCloudKit") private var isUsingCloudKit = false
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isExpanded = false
    
    enum SyncStatus: Equatable {
        case checking
        case synced
        case notSynced
        case error(String)
    }
    
    private var isErrorStatus: Bool {
        if case .error = syncStatus {
            return true
        }
        return false
    }
    
    var body: some View {
        Section {
            VStack(spacing: 0) {
                // Main row
                Button {
                    if syncStatus == .notSynced || isErrorStatus {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            isExpanded.toggle()
                        }
                        SensoryFeedback.light()
                    }
                } label: {
                    HStack(spacing: 14) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.15))
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Circle()
                                        .strokeBorder(statusColor.opacity(0.3), lineWidth: 0.5)
                                }
                            
                            statusIconImage
                        }
                        
                        // Text
                        VStack(alignment: .leading, spacing: 3) {
                            Text("iCloud Sync")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 4) {
                                switch syncStatus {
                                case .checking:
                                    Text("Checking...")
                                        .foregroundStyle(.white.opacity(0.6))
                                case .synced:
                                    Text("Active")
                                        .foregroundStyle(statusColor)
                                case .notSynced:
                                    Text("Not signed in")
                                        .foregroundStyle(statusColor)
                                case .error(let message):
                                    Text(message)
                                        .foregroundStyle(statusColor)
                                }
                                
                                if let status = accountStatus, syncStatus == .notSynced {
                                    Text("•")
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text(shortStatusText(status))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .font(.system(size: 14))
                        }
                        
                        Spacer()
                        
                        // Chevron
                        if syncStatus == .notSynced || isErrorStatus {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.3))
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                .disabled(syncStatus == .synced || syncStatus == .checking)
                
                // Expandable content - no sliding, just opacity
                if syncStatus == .notSynced || isErrorStatus {
                    VStack(spacing: 0) {
                        // Separator
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 0) {
                            // Steps
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(troubleshootingSteps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1).")
                                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                                            .foregroundStyle(themeManager.currentTheme.primaryAccent)
                                            .frame(width: 20, alignment: .leading)
                                        
                                        Text(step)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            
                            // Button
                            Button {
                                SensoryFeedback.light()
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.system(size: 15))
                                    Text("Open Settings")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundStyle(themeManager.currentTheme.primaryAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                                        .fill(themeManager.currentTheme.primaryAccent.opacity(0.12))
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(maxHeight: isExpanded ? nil : 0)
                    .opacity(isExpanded ? 1 : 0)
                    .clipped()
                }
                
                // Success state
                if syncStatus == .synced {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                        
                        HStack {
                            Label {
                                Text("Last sync")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.5))
                            } icon: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            
                            Spacer()
                            
                            Text("Just now")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            }
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.86, blendDuration: 0.2), value: isExpanded)
        } header: {
            // Clean - no header
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .task {
            await checkCloudKitStatus()
        }
    }
    
    @ViewBuilder
    private var statusIconImage: some View {
        switch syncStatus {
        case .checking:
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        case .synced:
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(statusColor)
        case .notSynced:
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(statusColor)
        case .error:
            Image(systemName: "xmark.icloud")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch syncStatus {
        case .checking:
            return .white.opacity(0.6)
        case .synced:
            return Color(red: 0.3, green: 0.8, blue: 0.4)
        case .notSynced:
            return themeManager.currentTheme.primaryAccent
        case .error:
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
    }
    
    private var troubleshootingSteps: [String] {
        [
            "Sign in to iCloud in Settings app",
            "Check your internet connection",
            "Enable iCloud Drive in Settings",
            "Force quit and restart Epilogue"
        ]
    }
    
    private func shortStatusText(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .noAccount:
            return "No account"
        case .restricted:
            return "Restricted"
        case .temporarilyUnavailable:
            return "Unavailable"
        case .couldNotDetermine:
            return "Unknown"
        @unknown default:
            return "Error"
        }
    }
    
    private func checkCloudKitStatus() async {
        do {
            let container = CKContainer(identifier: "iCloud.com.krispuckett.Epilogue")
            accountStatus = try await container.accountStatus()
            
            switch accountStatus {
            case .available:
                if isUsingCloudKit {
                    syncStatus = .synced
                } else {
                    syncStatus = .notSynced
                }
            case .noAccount:
                syncStatus = .notSynced
            case .restricted:
                syncStatus = .error("Restricted")
            case .temporarilyUnavailable:
                syncStatus = .error("Temporarily unavailable")
            default:
                syncStatus = .error("Unknown error")
            }
        } catch {
            syncStatus = .error("Connection failed")
        }
        
        isChecking = false
    }
}