import Foundation
import Combine

class WakeWordDetector: ObservableObject {
    @Published var isWakeWordDetected = false
    @Published var confidence: Float = 0.0
    @Published var lastDetectedTime: Date?
    
    private let wakeWords = [
        "epilogue",
        "hey epilogue",
        "ok epilogue",
        "hello epilogue"
    ]
    
    private let phoneticVariations: [String: [String]] = [
        "epilogue": ["epilog", "epi log", "epi-log", "epilogue"],
        "hey": ["hey", "hay", "hi"],
        "ok": ["ok", "okay", "o.k.", "o kay"],
        "hello": ["hello", "hallo", "hullo"]
    ]
    
    private var detectionCooldown: TimeInterval = 2.0
    private var cancellables = Set<AnyCancellable>()
    
    func detectWakeWord(in text: String) -> (detected: Bool, confidence: Float) {
        // Check if we're still in cooldown
        if let lastTime = lastDetectedTime,
           Date().timeIntervalSince(lastTime) < detectionCooldown {
            return (false, 0.0)
        }
        
        let lowercasedText = text.lowercased()
        var maxConfidence: Float = 0.0
        var detected = false
        
        for wakeWord in wakeWords {
            // Direct match
            if lowercasedText.contains(wakeWord) {
                detected = true
                maxConfidence = 1.0
                break
            }
            
            // Fuzzy matching with confidence score
            let confidence = fuzzyMatch(text: lowercasedText, target: wakeWord)
            if confidence > 0.8 {
                detected = true
                maxConfidence = max(maxConfidence, confidence)
            }
        }
        
        if detected {
            DispatchQueue.main.async {
                self.isWakeWordDetected = true
                self.confidence = maxConfidence
                self.lastDetectedTime = Date()
                
                // Auto-reset after cooldown
                DispatchQueue.main.asyncAfter(deadline: .now() + self.detectionCooldown) {
                    self.isWakeWordDetected = false
                }
            }
        }
        
        return (detected, maxConfidence)
    }
    
    private func fuzzyMatch(text: String, target: String) -> Float {
        // Split into words for better matching
        let textWords = text.split(separator: " ").map { String($0) }
        let targetWords = target.split(separator: " ").map { String($0) }
        
        // Check if target words appear in sequence
        var matchScore: Float = 0.0
        var lastFoundIndex = -1
        
        for targetWord in targetWords {
            var wordFound = false
            
            for (index, textWord) in textWords.enumerated() where index > lastFoundIndex {
                // Check phonetic variations
                if let variations = phoneticVariations[targetWord] {
                    if variations.contains(textWord) {
                        wordFound = true
                        lastFoundIndex = index
                        matchScore += 1.0
                        break
                    }
                }
                
                // Check direct match or close match
                if textWord == targetWord || levenshteinDistance(textWord, targetWord) <= 1 {
                    wordFound = true
                    lastFoundIndex = index
                    matchScore += 1.0
                    break
                }
            }
            
            if !wordFound {
                // Partial credit for similar words
                for (index, textWord) in textWords.enumerated() where index > lastFoundIndex {
                    let distance = levenshteinDistance(textWord, targetWord)
                    if distance <= 2 {
                        lastFoundIndex = index
                        matchScore += 0.5
                        break
                    }
                }
            }
        }
        
        return matchScore / Float(targetWords.count)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }
        
        return matrix[m][n]
    }
    
    func reset() {
        isWakeWordDetected = false
        confidence = 0.0
        lastDetectedTime = nil
    }
}