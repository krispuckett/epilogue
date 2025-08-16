import SwiftUI
import SwiftData

struct SessionSummaryPlaceholderView: View {
    let note: CapturedNote?
    let quote: CapturedQuote?
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [AmbientSession]
    
    private var matchingSession: AmbientSession? {
        // Debug logging
        print("🔍 Looking for session:")
        print("  - Note: \(note?.content.prefix(30) ?? "nil")")
        print("  - Quote: \(quote?.text.prefix(30) ?? "nil")")
        print("  - Note session: \(note?.ambientSession?.id ?? UUID())")
        print("  - Quote session: \(quote?.ambientSession?.id ?? UUID())")
        print("  - Available sessions: \(sessions.count)")
        
        // Use direct relationship if available
        if let noteSession = note?.ambientSession {
            print("✅ Found session via note relationship")
            return noteSession
        }
        if let quoteSession = quote?.ambientSession {
            print("✅ Found session via quote relationship")
            return quoteSession
        }
        
        // Fallback to timestamp matching for older data
        let targetDate = note?.timestamp ?? quote?.timestamp ?? Date()
        print("🕓 Looking for session by timestamp: \(targetDate)")
        
        let found = sessions.first { session in
            let sessionStart = session.startTime
            let sessionEnd = session.endTime
            
            // Check if the note/quote was created during this session
            let matches = targetDate >= sessionStart && targetDate <= sessionEnd.addingTimeInterval(300) // 5 minute buffer
            if matches {
                print("✅ Found session by timestamp match")
            }
            return matches
        }
        
        if found == nil {
            print("❌ No matching session found")
        }
        
        return found
    }
    
    var body: some View {
        if let session = matchingSession {
            // Show the actual ambient session summary
            AmbientSessionSummaryView(
                session: session,
                colorPalette: nil
            )
        } else {
            // Show a fallback view when no session is found
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "waveform.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.white.opacity(0.3))
                
                Text("Session Details")
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                
                if let note = note {
                    VStack(spacing: 12) {
                        Text("Note from Ambient Session")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text(note.content)
                            .font(.system(size: 17))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Text(formatDate(note.timestamp))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                } else if let quote = quote {
                    VStack(spacing: 12) {
                        Text("Quote from Ambient Session")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text("\"\(quote.text)\"")
                            .font(.custom("Georgia", size: 20))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        if let author = quote.author {
                            Text("— \(author)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Text(formatDate(quote.timestamp))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.11, green: 0.105, blue: 0.102))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}