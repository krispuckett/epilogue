import SwiftUI
import SwiftData

struct SessionSummaryPlaceholderView: View {
    let note: CapturedNote?
    let quote: CapturedQuote?
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [AmbientSession]
    
    private var matchingSession: AmbientSession? {
        // Debug logging
        #if DEBUG
        print("🔍 Looking for session:")
        #endif
        #if DEBUG
        print("  - Note: \((note?.content ?? "").prefix(30))")
        #endif
        #if DEBUG
        print("  - Quote: \((quote?.text ?? "").prefix(30))")
        #endif
        #if DEBUG
        print("  - Note has session: \(note?.ambientSession != nil)")
        #endif
        #if DEBUG
        print("  - Quote has session: \(quote?.ambientSession != nil)")
        #endif
        if let noteSession = note?.ambientSession {
            #if DEBUG
            print("  - Note session ID: \(noteSession.id)")
            #endif
            #if DEBUG
            print("  - Note session book: \(noteSession.book?.title ?? "nil")")
            #endif
        }
        if let quoteSession = quote?.ambientSession {
            #if DEBUG
            print("  - Quote session ID: \(quoteSession.id)")
            #endif
            #if DEBUG
            print("  - Quote session book: \(quoteSession.book?.title ?? "nil")")
            #endif
        }
        #if DEBUG
        print("  - Available sessions: \(sessions.count)")
        #endif
        for (index, session) in sessions.enumerated() {
            #if DEBUG
            print("    Session \(index): \(session.id) - \(session.book?.title ?? "no book")")
            #endif
        }
        
        // Use direct relationship if available
        if let noteSession = note?.ambientSession {
            #if DEBUG
            print("✅ Found session via note relationship")
            #endif
            return noteSession
        }
        if let quoteSession = quote?.ambientSession {
            #if DEBUG
            print("✅ Found session via quote relationship")
            #endif
            return quoteSession
        }
        
        // Fallback to timestamp matching for older data
        let targetDate = note?.timestamp ?? quote?.timestamp ?? Date()
        #if DEBUG
        print("🕓 Looking for session by timestamp: \(targetDate)")
        #endif
        
        let found = sessions.first { session in
            let sessionStart = session.startTime
            let sessionEnd = session.endTime
            
            // Check if the note/quote was created during this session
            let matches = targetDate >= (sessionStart ?? Date()) && targetDate <= (sessionEnd ?? sessionStart ?? Date()).addingTimeInterval(300) // 5 minute buffer
            if matches {
                #if DEBUG
                print("✅ Found session by timestamp match")
                #endif
            }
            return matches
        }
        
        if found == nil {
            #if DEBUG
            print("❌ No matching session found")
            #endif
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
                    .foregroundStyle(DesignSystem.Colors.textQuaternary)
                
                Text("Session Details")
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                
                if let note = note {
                    VStack(spacing: 12) {
                        Text("Note from Ambient Session")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        
                        Text(note.content ?? "")
                            .font(.system(size: 17))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Text(formatDate(note.timestamp ?? Date()))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                } else if let quote = quote {
                    VStack(spacing: 12) {
                        Text("Quote from Ambient Session")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        
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
                        
                        Text(formatDate(quote.timestamp ?? Date()))
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
            .background(DesignSystem.Colors.surfaceBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(DesignSystem.Colors.textQuaternary)
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