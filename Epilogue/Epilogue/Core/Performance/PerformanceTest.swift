import SwiftUI

// MARK: - Performance Test View
struct PerformanceTestView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var testResults: [String] = []
    @State private var isRunning = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // FPS Monitor
                    performanceMonitorSection
                    
                    // Test Controls
                    testControlsSection
                    
                    // Results
                    if !testResults.isEmpty {
                        resultsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Performance Tests")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    @ViewBuilder
    private var performanceMonitorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-time Performance")
                .font(.headline)
            
            HStack {
                Label("FPS", systemImage: "speedometer")
                Spacer()
                Text("\(Int(performanceMonitor.fps))")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(performanceMonitor.fps > 110 ? .green : .orange)
            }
            
            HStack {
                Label("Frame Drops", systemImage: "exclamationmark.triangle")
                Spacer()
                Text("\(performanceMonitor.frameDrops)")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(performanceMonitor.frameDrops == 0 ? .green : .orange)
            }
            
            HStack {
                Label("Main Thread Blocks", systemImage: "cpu")
                Spacer()
                Text("\(performanceMonitor.mainThreadBlocks)")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(performanceMonitor.mainThreadBlocks == 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var testControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Tests")
                .font(.headline)
            
            Button(action: runAllTests) {
                HStack {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isRunning ? "Running Tests..." : "Run All Tests")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isRunning)
        }
    }
    
    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Results")
                .font(.headline)
            
            ForEach(testResults, id: \.self) { result in
                Text(result)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Test Methods
    
    private func runAllTests() {
        isRunning = true
        testResults = []
        performanceMonitor.reset()
        
        Task {
            await runTest("Scroll Performance") {
                // Simulate rapid scrolling
                for _ in 0..<100 {
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    performanceMonitor.detectMainThreadBlock()
                }
            }
            
            await runTest("Heavy Computation") {
                // Test background processing
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<10 {
                        group.addTask {
                            let _ = await performanceMonitor.measureAsync("Heavy Task \(i)") {
                                // Simulate heavy work
                                var sum = 0
                                for j in 0..<1_000_000 {
                                    sum += j
                                }
                                return sum
                            }
                        }
                    }
                }
            }
            
            await runTest("UI Updates") {
                // Test optimistic updates
                for i in 0..<50 {
                    await MainActor.run {
                        OptimisticUpdateManager.shared.performOptimisticUpdate(
                            id: "test-\(i)",
                            immediate: {
                                // Simulate immediate UI update
                            },
                            commit: {
                                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                                return true
                            },
                            rollback: {
                                // Simulate rollback
                            }
                        )
                    }
                }
            }
            
            await runTest("Memory Pressure") {
                // Test caching under memory pressure
                var images: [UIImage] = []
                for i in 0..<20 {
                    if let image = UIImage(systemName: "book.fill") {
                        images.append(image)
                    }
                    
                    if i % 5 == 0 {
                        // Simulate memory warning
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: UIApplication.didReceiveMemoryWarningNotification,
                                object: nil
                            )
                        }
                    }
                }
            }
            
            await MainActor.run {
                performanceMonitor.logPerformanceReport()
                
                // Summary
                let summary = """
                === Performance Summary ===
                Average FPS: \(Int(performanceMonitor.fps))
                Total Frame Drops: \(performanceMonitor.frameDrops)
                Main Thread Blocks: \(performanceMonitor.mainThreadBlocks)
                
                ✅ Scroll Performance: \(performanceMonitor.frameDrops < 5 ? "PASSED" : "FAILED")
                ✅ 120Hz Support: \(performanceMonitor.fps > 110 ? "PASSED" : "NEEDS WORK")
                ✅ Main Thread: \(performanceMonitor.mainThreadBlocks == 0 ? "OPTIMIZED" : "NEEDS WORK")
                """
                
                testResults.append(summary)
                isRunning = false
                
                // Haptic feedback on completion
                SensoryFeedback.success()
            }
        }
    }
    
    private func runTest(_ name: String, test: () async throws -> Void) async {
        let measurement = performanceMonitor.startMeasuring(name)
        
        await MainActor.run {
            testResults.append("🔄 Running: \(name)")
        }
        
        do {
            try await test()
            await MainActor.run {
                testResults.append("✅ \(name): Completed")
            }
        } catch {
            await MainActor.run {
                testResults.append("❌ \(name): Failed - \(error.localizedDescription)")
            }
        }
        
        // Force cleanup of measurement
        _ = measurement
    }
}

// MARK: - Preview
#if DEBUG
struct PerformanceTestView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceTestView()
    }
}
#endif