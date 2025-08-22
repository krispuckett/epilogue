import Foundation
import UIKit
import os.log

/// Monitors and reports on image cache usage
@MainActor
final class ImageCacheMonitor: ObservableObject {
    static let shared = ImageCacheMonitor()
    
    @Published var memoryUsage: String = "0 MB"
    @Published var diskUsage: String = "0 MB"
    @Published var totalImages: Int = 0
    
    private let logger = Logger(subsystem: "com.epilogue", category: "ImageCache")
    private var monitorTimer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        monitorTimer?.invalidate()
    }
    
    /// Start monitoring cache stats
    private func startMonitoring() {
        // Update immediately
        updateStats()
        
        // Update every 30 seconds
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                self.updateStats()
            }
        }
    }
    
    /// Update cache statistics
    private func updateStats() {
        let stats = SharedBookCoverManager.shared.getCacheStats()
        
        // Format memory usage
        let memoryMB = Double(stats.memoryUsage) / (1024 * 1024)
        memoryUsage = String(format: "%.1f MB", memoryMB)
        
        // Format disk usage
        let diskMB = Double(stats.diskUsage) / (1024 * 1024)
        diskUsage = String(format: "%.1f MB", diskMB)
        
        // Log if usage is high
        if memoryMB > 30 {
            logger.warning("High memory cache usage: \(memoryMB, format: .fixed(precision: 1)) MB")
        }
        
        if diskMB > 80 {
            logger.warning("High disk cache usage: \(diskMB, format: .fixed(precision: 1)) MB")
        }
    }
    
    /// Clear all caches
    func clearCaches() {
        SharedBookCoverManager.shared.clearAllCaches()
        updateStats()
        logger.info("Image caches cleared")
    }
    
    /// Get detailed cache report
    func getDetailedReport() -> String {
        let stats = SharedBookCoverManager.shared.getCacheStats()
        
        let memoryMB = Double(stats.memoryUsage) / (1024 * 1024)
        let diskMB = Double(stats.diskUsage) / (1024 * 1024)
        
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = Double(processInfo.physicalMemory) / (1024 * 1024 * 1024) // GB
        
        return """
        📊 Image Cache Report
        ━━━━━━━━━━━━━━━━━━━━
        
        Memory Cache:
        • Usage: \(String(format: "%.1f", memoryMB)) MB
        • Limit: 60 MB (50MB full + 10MB thumbs)
        
        Disk Cache:
        • Usage: \(String(format: "%.1f", diskMB)) MB
        • Limit: 100 MB
        • Location: ~/Library/Caches/BookCovers
        
        System:
        • Physical Memory: \(String(format: "%.1f", physicalMemory)) GB
        • Process Memory: \(String(format: "%.1f", Double(getMemoryUsage()) / (1024 * 1024))) MB
        
        Optimization Tips:
        • Caches auto-clear on memory warnings
        • Old items removed after 7 days
        • Thumbnails cached separately
        """
    }
    
    /// Get current process memory usage
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<natural_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         ptr,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

/// Debug view for Settings
struct ImageCacheDebugView: View {
    @StateObject private var monitor = ImageCacheMonitor.shared
    @State private var showingReport = false
    
    var body: some View {
        Section("Image Cache") {
            HStack {
                Label("Memory", systemImage: "memorychip")
                Spacer()
                Text(monitor.memoryUsage)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Label("Disk", systemImage: "internaldrive")
                Spacer()
                Text(monitor.diskUsage)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                showingReport = true
            } label: {
                Label("View Detailed Report", systemImage: "chart.bar.doc.horizontal")
            }
            
            Button(role: .destructive) {
                monitor.clearCaches()
                HapticManager.shared.success()
            } label: {
                Label("Clear All Caches", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $showingReport) {
            NavigationView {
                ScrollView {
                    Text(monitor.getDetailedReport())
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Cache Report")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingReport = false
                        }
                    }
                }
            }
        }
    }
}