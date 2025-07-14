//
//  UniversalCommandBar 2.swift
//  Epilogue
//
//  Created by Kris Puckett on 7/13/25.
//


import SwiftUI

struct UniversalCommandBar: View {
    @Binding var selectedTab: Int
    @State private var isExpanded = false
    @State private var commandText = ""
    @State private var detectedIntent: CommandIntent = .unknown
    @State private var showBookSearch = false
    @State private var suggestions: [CommandSuggestion] = []
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool
    @Namespace private var animation
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Suggestions overlay - positioned above the command bar
            if isExpanded && showSuggestions {
                VStack {
                    Spacer()
                    CommandSuggestionsView(suggestions: suggestions) { suggestion in
                        commandText = suggestion.text
                        detectedIntent = suggestion.intent
                        executeCommand()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Adjusted for proper positioning
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
            
            // Main content that switches between tab bar and command bar
            Group {
                if isExpanded {
                    // Expanded command bar
                    HStack(spacing: 12) {
                        // Collapse button
                        Button(action: collapse) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 44, height: 44)
                        }
                        .glassEffect(.regular, in: Circle())
                        
                        // Command input field
                        HStack(spacing: 12) {
                            Image(systemName: detectedIntent.icon)
                                .foregroundStyle(detectedIntent.color)
                                .font(.system(size: 20))
                                .animation(.spring(response: 0.3), value: detectedIntent)
                            
                            TextField("What's on your mind?", text: $commandText)
                                .textFieldStyle(.plain)
                                .font(.bodyLarge)
                                .foregroundStyle(.white)
                                .focused($isFocused)
                                .onChange(of: commandText) { _, new in
                                    detectedIntent = CommandParser.parse(new)
                                    suggestions = CommandSuggestion.suggestions(for: new)
                                    showSuggestions = !new.isEmpty
                                }
                                .onSubmit {
                                    executeCommand()
                                }
                            
                            if !commandText.isEmpty {
                                Button(action: executeCommand) {
                                    Text(detectedIntent.actionText)
                                        .font(.labelMedium)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(detectedIntent.color)
                                        .clipShape(Capsule())
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    
                } else {
                    // Normal state - tab bar with floating orb
                    HStack(spacing: 12) {
                        // Tab bar
                        HStack(spacing: 0) {
                            TabBarItem(
                                icon: "books.vertical",
                                label: "Library",
                                isSelected: selectedTab == 0
                            ) {
                                selectedTab = 0
                            }
                            
                            TabBarItem(
                                icon: "note.text",
                                label: "Notes",
                                isSelected: selectedTab == 1
                            ) {
                                selectedTab = 1
                            }
                            
                            TabBarItem(
                                icon: "message",
                                label: "Chat",
                                isSelected: selectedTab == 2
                            ) {
                                selectedTab = 2
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 65)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32.5))
                        
                        // Plus button - smaller floating orb
                        Button(action: expand) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                        }
                        .glassEffect(.thick, in: Circle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: showSuggestions)
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(searchQuery: CommandParser.parse(commandText).bookQuery ?? commandText)
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                // Ensure focus happens after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func expand() {
        withAnimation {
            isExpanded = true
        }
    }
    
    private func collapse() {
        withAnimation {
            isExpanded = false
            commandText = ""
            detectedIntent = .unknown
            isFocused = false
            showSuggestions = false
        }
    }
    
    private func executeCommand() {
        switch detectedIntent {
        case .addBook:
            showBookSearch = true
        case .createQuote(let text):
            saveQuote(text)
        case .createNote(let text):
            saveNote(text)
        case .searchLibrary(let query):
            searchLibrary(query)
        case .unknown:
            break
        }
    }
    
    private func saveQuote(_ text: String) {
        // TODO: Implement quote saving
        collapse()
    }
    
    private func saveNote(_ text: String) {
        // TODO: Implement note saving
        collapse()
    }
    
    private func searchLibrary(_ query: String) {
        // TODO: Implement library search
        collapse()
    }
}

// MARK: - Tab Bar Item
struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .symbolVariant(isSelected ? .fill : .none)
                
                Text(label)
                    .font(.labelSmall)
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Extensions
extension CommandIntent {
    var bookQuery: String? {
        switch self {
        case .addBook(let query):
            return query
        default:
            return nil
        }
    }
}

#Preview {
    ZStack {
        // Colorful gradient background to test glass effects
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.2, blue: 0.5),
                Color(red: 0.3, green: 0.1, blue: 0.4),
                Color(red: 0.2, green: 0.3, blue: 0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack {
            Spacer()
            UniversalCommandBar(selectedTab: .constant(0))
        }
    }
}