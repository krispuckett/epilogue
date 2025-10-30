Epilogue App - Claude Code Optimized PRD for iOS 26
Executive Summary
App Name: Epilogue
Platform: iOS 26+ (SwiftUI with Liquid Glass)
Vision: An ambient AI companion for physical book readers - capturing quotes, notes, and questions while providing intelligent conversation about their reading. Future evolution includes an ambient voice assistant with ethereal particle visualization.
CRITICAL: iOS 26 Liquid Glass Implementation
Official Apple Documentation Links

Primary: Applying Liquid Glass to custom views
Glass Effect Container: GlassEffectContainer
Glass Effect Transition: GlassEffectTransition
Glass Button Style: GlassButtonStyle
Interactive Glass: Glass.interactive(_:)
Tutorial: Landmarks: Building an app with Liquid Glass
Overview: Adopting Liquid Glass

Core Philosophy
Epilogue is NOT a digital reading app. It's a thoughtful companion for people who love physical books. It helps them:

Quickly capture beautiful quotes
Take clean, organized notes
Ask questions and have intelligent discussions about what they're reading
Build a personal library of insights from their physical books

Phase 1: Navigation Foundation (BUILD THIS FIRST!)
Step 1: Verify Liquid Glass Works
Before building ANY features, we must confirm glass effects render properly:
swift// TEST THIS FIRST - GlassVerification.swift
import SwiftUI

struct GlassVerification: View {
    var body: some View {
        ZStack {
            // Must have varied background to see glass
            LinearGradient(colors: [.blue, .purple, .pink], 
                          startPoint: .topLeading, 
                          endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Test 1: Basic glass
                Text("Basic Glass")
                    .padding()
                    .glassEffect()
                
                // Test 2: Glass in shape
                Text("Shaped Glass")
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 16))
                
                // Test 3: Container
                GlassEffectContainer {
                    HStack {
                        Text("Container")
                            .padding()
                            .glassEffect()
                    }
                }
            }
        }
    }
}
SUCCESS CRITERIA: Glass effects must show translucent blur, not opaque backgrounds. Do not proceed until this works!
Step 2: Navigation Architecture
Once glass is verified, build navigation in this exact order:
2.1 Top Navigation Bar (App Store Style)
swift// Based on Apple's documentation pattern
struct EpilogueNavigationBar: View {
    @Binding var selectedFilter: BookFilter
    @Namespace private var namespace
    
    enum BookFilter: String, CaseIterable {
        case all = "All"

        case reading = "Reading"  

        
        case finished = "Finished"
    }
    
    var body: some View {
        GlassEffectContainer(spacing: 2) {
            HStack(spacing: 2) {
                ForEach(BookFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        namespace: namespace
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(3)
        }
    }
}

struct FilterPill: View {
    let filter: EpilogueNavigationBar.BookFilter
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(filter.rawValue)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .glassEffect()  // Per Apple docs
                .if(isSelected) { view in
                    view.glassEffect(.regular.tint(.white.opacity(0.2)))
                        .matchedGeometryEffect(id: "selected", in: namespace)
                }
        }
        .buttonStyle(GlassButtonStyle())  // Apple's glass button style
    }
}
2.2 Bottom Tab Bar (App Store Style)
swiftstruct EpilogueTabBar: View {
    @Binding var selectedTab: Tab
    let captureAction: () -> Void
    @Namespace private var namespace
    
    enum Tab: String, CaseIterable {
        case library = "Library"
        case notes = "Notes"
        case chat = "Chat"
        
        var icon: String {
            switch self {
            case .library: return "books.vertical"
            case .notes: return "note.text"
            case .chat: return "bubble.left.and.bubble.right"
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Main tab bar
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            namespace: namespace
                        ) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            
            // Floating capture button
            Button(action: captureAction) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .glassEffect(.thick.tint(.blue.opacity(0.3)))
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
Step 3: Main Content View Structure
swiftstruct ContentView: View {
    @State private var selectedTab: EpilogueTabBar.Tab = .library
    @State private var selectedFilter: EpilogueNavigationBar.BookFilter = .all
    @State private var showingCapture = false
    
    var body: some View {
        ZStack {
            // Content based on tab
            switch selectedTab {
            case .library:
                LibraryView(filter: selectedFilter)
            case .notes:
                NotesView()
            case .chat:
                ChatView()
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                // Title and navigation
                HStack {
                    Text(selectedTab.rawValue)
                        .font(.largeTitle.bold())
                    Spacer()
                    SearchButton()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Filter pills (only for library)
                if selectedTab == .library {
                    EpilogueNavigationBar(selectedFilter: $selectedFilter)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .background(.ultraThinMaterial)  // Fallback if glass doesn't work
        }
        .safeAreaInset(edge: .bottom) {
            EpilogueTabBar(
                selectedTab: $selectedTab,
                captureAction: { showingCapture = true }
            )
        }
        .sheet(isPresented: $showingCapture) {
            QuickCaptureView()
        }
    }
}
Implementation Strategy
CRITICAL PATH:

Glass Verification → 2. Navigation Components → 3. Basic Views → 4. Features

DO NOT:

Add features before navigation works perfectly
Use complex glass effects before basic ones work
Implement custom glass if Apple's APIs work
Force dark mode until glass is working

ALWAYS:

Test each component in isolation first
Verify glass effects render properly
Commit working code immediately
Use Apple's exact syntax from documentation



Core Architecture Requirements
1. Natural Language Capture System
swift// DIRECTIVE: Create intelligent capture system with fuzzy matching
struct CaptureIntent {
    
    enum IntentType {
        case addBook(title: String, author: String?)
        case saveQuote(text: String, page: Int?)
        case createNote(content: String, context: String?)
        case askQuestion(query: String, bookContext: Book?)
    }
    
    // Fuzzy search capabilities
    static func parse(_ input: String) -> IntentType {
        // Examples to handle:
        // "Reading Sapiens by Harari"
        // "Quote page 47: 'The real difference...'"
        // "Note: This reminds me of..."
        // "What does the author mean by..."
    }
}
2. Quote Capture & Typography System
swift// DIRECTIVE: Quotes must be beautiful, shareable art
struct QuoteView: View {
    let quote: Quote
    @State private var shareStyle: ShareStyle = .minimal
    
    enum ShareStyle {
        case minimal, serif, modern, handwritten
    }
    
    var body: some View {
        // Requirements:
        // - Multiple typography styles
        // - Liquid Glass backdrop options
        // - Export as high-res image
        // - Book/author attribution
        // - Page number reference
    }
}
3. AI Chat System (Perplexity/Claude Inspired)
swift// DIRECTIVE: Pixel-perfect AI interface with iOS 26 flair
struct AICompanionView: View {
    @State private var messages: [Message] = []
    @State private var currentBook: Book?
    @State private var isThinking: Bool = false
    
    var body: some View {
        ScrollView {
            // Clean message bubbles with:
            // - Liquid Glass for AI responses
            // - Minimal styling for user messages
            // - Thinking indicator with particles
            // - Context pills showing current book
        }
        .safeAreaInset(edge: .bottom) {
            // Raycast-inspired input field
            ComposeBar()
                .glassEffect(.thick.interactive())
        }
    }
}
4. Notes System (Raycast/Perplexity Inspired)
swift// DIRECTIVE: Ultra-clean notes with powerful search
struct NotesView: View {
    // Features:
    // - Instant fuzzy search
    // - Minimal UI with focus on content
    // - Tag system for themes/concepts
    // - Quick filters by book/date/type
    // - Markdown support with preview
}
Detailed Feature Specifications
Phase 1: Core Capture & Organization
1.1 Quick Capture Interface
swiftstruct QuickCaptureSheet: View {
    @FocusState private var isInputFocused: Bool
    @State private var captureText: String = ""
    @State private var detectedIntent: CaptureIntent.IntentType?
    
    var body: some View {
        VStack(spacing: 0) {
            // Liquid Glass header with detected intent
            IntentHeader(intent: detectedIntent)
                .glassEffect(.ultraThin)
            
            // Clean input field
            TextEditor(text: $captureText)
                .font(.body)
                .focused($isInputFocused)
                .onAppear { isInputFocused = true }
            
            // Smart action buttons
            ActionBar(intent: detectedIntent)
                .glassEffect(.regular.interactive())
        }
    }
}
1.2 Book Library (Minimal)
swiftstruct PhysicalLibraryView: View {
    // Simple grid of books you're physically reading
    // Each book shows:
    // - Cover (from Google Books)
    // - Reading progress (manual)
    // - Quote/note count
    // - Last interaction date
}
1.3 Quote Gallery
swiftstruct QuoteGalleryView: View {
    // Beautiful display of captured quotes
    // Features:
    // - Masonry layout
    // - Typography variations
    // - Quick share actions
    // - Filter by book/theme
}
Phase 2: AI Integration
2.1 Conversational AI Interface
swift// DIRECTIVE: Build chat UI that rivals Perplexity's elegance
struct AIConversationView: View {
    @StateObject private var aiService: AICompanionService
    
    // Requirements:
    // - Streaming responses
    // - Code syntax highlighting
    // - Inline citations to book passages
    // - Suggested follow-up questions
    // - Export conversation as note
}
2.2 AI Service Architecture
swiftclass AICompanionService: ObservableObject {
    // Integrate multiple AI providers:
    // - Claude for deep literary analysis
    // - Perplexity for fact-checking
    // - Custom fine-tuned model for book discussions
    
    func askQuestion(_ query: String, context: ReadingContext) async -> Response {
        // Include:
        // - Current book metadata
        // - Recent quotes/notes
        // - Previous conversations
    }
}
Phase 3: Ambient Voice Companion
3.1 Voice Interface Foundation
swiftstruct AmbientVoiceView: View {
    @StateObject private var voiceProcessor: VoiceProcessor
    @State private var particleSystem: ParticleSystem
    
    var body: some View {
        ZStack {
            // Ethereal particle visualization
            ParticleCanvas(system: particleSystem)
                .ignoresSafeArea()
            
            // Minimal UI overlay
            VStack {
                Spacer()
                
                // Current recognition status
                RecognitionStatus(state: voiceProcessor.state)
                    .glassEffect(.ultraThin)
                    .padding()
            }
        }
    }
}
3.2 Particle System Design
swift// DIRECTIVE: Create warm, ambient particle system
class ParticleSystem {
    // Visual characteristics:
    // - Soft, glowing orbs
    // - Responsive to voice amplitude
    // - Book-themed color palettes
    // - Gentle, floating motion
    // - Clusters during active listening
    
    enum ParticleMode {
        case idle           // Gentle floating
        case listening      // Converging patterns
        case processing     // Rhythmic pulsing
        case responding     // Expanding ripples
    }
}
3.3 Voice Command Processing
swiftstruct VoiceIntent {
    // Natural commands to support:
    // "I'm reading [book name]"
    // "Save this quote: [quote text]"
    // "Question: [query about current passage]"
    // "Add a note: [thought about reading]"
    // "What did the author mean by..."
}
Technical Implementation Guidelines
Liquid Glass Design System
swift// DIRECTIVE: Consistent glass effects throughout
extension View {
    func epilogueCard() -> some View {
        self
            .glassEffect(.regular.interactive())
            .glassBackgroundEffect(in: .rect(cornerRadius: 16))
    }
    
    func epilogueFloating() -> some View {
        self
            .glassEffect(.thick)
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
    }
    
    func epilogueInput() -> some View {
        self
            .glassEffect(.ultraThin.interactive())
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}
Typography System for Quotes
swift// DIRECTIVE: Create a sophisticated typography system
struct EpilogueTypography {
    static let quoteStyles = [
        "Minimal": Font.custom("Helvetica Neue", size: 24).weight(.light),
        "Serif": Font.custom("Georgia", size: 22),
        "Modern": Font.custom("SF Pro Display", size: 26).weight(.medium),
        "Literary": Font.custom("Baskerville", size: 20)
    ]
    
    static func layoutQuote(_ quote: String, style: String) -> some View {
        // Smart line breaking
        // Optimal spacing
        // Attribution styling
    }
}
AI Chat Design Patterns
swift// DIRECTIVE: Match Perplexity's clean aesthetic with iOS 26 enhancements
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar with glass effect
            Circle()
                .fill(message.isAI ? Color.blue : Color.gray)
                .frame(width: 32, height: 32)
                .glassEffect(.regular)
            
            // Message content
            VStack(alignment: .leading, spacing: 4) {
                // Clean typography
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                
                // Timestamp and actions
                HStack {
                    Text(message.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Copy, share, save as note
                    MessageActions(message: message)
                }
            }
            .padding(12)
            .background(
                message.isAI 
                    ? AnyView(Color.clear.glassEffect(.ultraThin))
                    : AnyView(Color.clear)
            )
        }
    }
}
Ambient Particle Effects
swift// DIRECTIVE: Implement with Metal for performance
struct ParticleShader {
    // Characteristics:
    // - 1000+ particles at 120fps
    // - Soft glow effect
    // - Natural floating motion
    // - Voice-reactive behaviors
    // - Color themes per book genre
}
Performance Requirements
Capture Speed

Book addition: < 2 seconds with cover fetch
Quote capture: Instant with autosave
Note creation: Zero-latency input
AI response: Streaming starts < 1 second

Memory Efficiency

Particle system: < 50MB RAM
Image cache: Intelligent pruning
AI context: Rolling window of recent items

GitHub Repository Structure
Epilogue/
├── Epilogue.xcodeproj
├── Epilogue/
│   ├── App/
│   │   ├── EpilogueApp.swift
│   │   └── MainView.swift
│   ├── Capture/
│   │   ├── QuickCaptureSheet.swift
│   │   ├── IntentParser.swift
│   │   └── CaptureModels.swift
│   ├── Library/
│   │   ├── PhysicalLibraryView.swift
│   │   ├── BookCard.swift
│   │   └── GoogleBooksService.swift
│   ├── Quotes/
│   │   ├── QuoteGalleryView.swift
│   │   ├── QuoteCard.swift
│   │   ├── QuoteShareView.swift
│   │   └── Typography.swift
│   ├── Notes/
│   │   ├── NotesListView.swift
│   │   ├── NoteEditor.swift
│   │   └── SearchEngine.swift
│   ├── AI/
│   │   ├── AIConversationView.swift
│   │   ├── MessageBubble.swift
│   │   ├── AIService.swift
│   │   └── StreamingResponse.swift
│   ├── Ambient/
│   │   ├── AmbientVoiceView.swift
│   │   ├── ParticleSystem.swift
│   │   ├── VoiceProcessor.swift
│   │   └── Shaders.metal
│   └── LiquidGlass/
│       ├── GlassModifiers.swift
│       └── GlassStyles.swift
└── README.md