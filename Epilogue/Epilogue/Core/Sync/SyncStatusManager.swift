import SwiftUI
import Combine
import Network

// MARK: - Sync Status
enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case error(String)
    case offline
    case conflict(Int) // Number of conflicts
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.offline, .offline):
            return true
        case (.synced(let date1), .synced(let date2)):
            return date1.timeIntervalSince1970 == date2.timeIntervalSince1970
        case (.error(let msg1), .error(let msg2)):
            return msg1 == msg2
        case (.conflict(let count1), .conflict(let count2)):
            return count1 == count2
        default:
            return false
        }
    }
}

// MARK: - Sync Status Manager
@MainActor
final class SyncStatusManager: ObservableObject {
    static let shared = SyncStatusManager()
    
    @Published private(set) var status: SyncStatus = .idle
    @Published private(set) var isOnline = true
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingChanges = 0
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNetworkMonitoring()
        loadLastSyncDate()
    }
    
    // MARK: - Public Methods
    
    func startSync() {
        guard isOnline else {
            status = .offline
            return
        }
        
        status = .syncing
        
        // Simulate sync process
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                let now = Date()
                lastSyncDate = now
                status = .synced(now)
                pendingChanges = 0
                saveLastSyncDate()
            }
        }
    }
    
    func reportError(_ message: String) {
        status = .error(message)
    }
    
    func reportConflicts(_ count: Int) {
        status = .conflict(count)
    }
    
    func incrementPendingChanges() {
        pendingChanges += 1
        if case .synced = status {
            status = .idle
        }
    }
    
    func reset() {
        status = .idle
        pendingChanges = 0
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let wasOnline = self.isOnline
                self.isOnline = path.status == .satisfied
                
                if !wasOnline && self.isOnline {
                    // Back online - trigger sync
                    self.startSync()
                } else if !self.isOnline {
                    self.status = .offline
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        if let lastSync = lastSyncDate {
            status = .synced(lastSync)
        }
    }
    
    private func saveLastSyncDate() {
        if let date = lastSyncDate {
            UserDefaults.standard.set(date, forKey: "lastSyncDate")
        }
    }
}

// MARK: - Sync Status View
struct SyncStatusView: View {
    @StateObject private var syncManager = SyncStatusManager.shared
    
    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            statusText
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .animation(DesignSystem.Animation.easeQuick, value: syncManager.status)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch syncManager.status {
        case .idle:
            if syncManager.pendingChanges > 0 {
                Image(systemName: "clock")
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            
        case .syncing:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 12, height: 12)
            
        case .synced:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
        case .offline:
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
            
        case .conflict:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        }
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch syncManager.status {
        case .idle:
            if syncManager.pendingChanges > 0 {
                Text("Pending")
            } else {
                Text("Synced")
            }
            
        case .syncing:
            Text("Syncing...")
            
        case .synced(let date):
            Text(formatSyncTime(date))
            
        case .error:
            Text("Error")
            
        case .offline:
            Text("Offline")
            
        case .conflict(let count):
            Text("\(count) conflict\(count == 1 ? "" : "s")")
        }
    }
    
    private func formatSyncTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Detailed Sync Status Sheet
struct DetailedSyncStatusSheet: View {
    @StateObject private var syncManager = SyncStatusManager.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Current Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Status")
                        .font(.headline)
                    
                    HStack {
                        SyncStatusView()
                        Spacer()
                        if syncManager.pendingChanges > 0 {
                            Text("\(syncManager.pendingChanges) pending")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Last Sync
                if let lastSync = syncManager.lastSyncDate {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Synced")
                            .font(.headline)
                        
                        Text(lastSync, style: .date)
                            .font(.body)
                        Text(lastSync, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Network Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Network")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: syncManager.isOnline ? "wifi" : "wifi.slash")
                            .foregroundStyle(syncManager.isOnline ? .green : .red)
                        Text(syncManager.isOnline ? "Connected" : "Offline")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Manual Sync Button
                Button(action: {
                    syncManager.startSync()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Sync Now")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
                .disabled(!syncManager.isOnline || syncManager.status == .syncing)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}