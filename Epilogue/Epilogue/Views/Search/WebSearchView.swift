import SwiftUI
import SwiftData

struct WebSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var searchService = PerplexitySearchService.shared
    @State private var searchQuery = ""
    @State private var searchResults: [SearchResult] = []
    @State private var selectedSearchType = SearchType.books
    @State private var showingAPIKeyAlert = false
    @State private var isFirstSearch = true
    
    enum SearchType: String, CaseIterable {
        case books = "Books"
        case trending = "Trending"
        case general = "Web"
        
        var icon: String {
            switch self {
            case .books: return "book.fill"
            case .trending: return "chart.line.uptrend.xyaxis"
            case .general: return "globe"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search type selector
                Picker("Search Type", selection: $selectedSearchType) {
                    ForEach(SearchType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search \(selectedSearchType.rawValue.lowercased())...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                            isFirstSearch = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Search") {
                        performSearch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchQuery.isEmpty || searchService.isSearching)
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Results or empty state
                if searchService.isSearching {
                    Spacer()
                    ProgressView("Searching...")
                        .foregroundColor(.secondary)
                    Spacer()
                } else if searchResults.isEmpty && !isFirstSearch {
                    Spacer()
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term or category")
                    )
                    Spacer()
                } else if !searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(searchResults) { result in
                                SearchResultRow(result: result)
                                    .onTapGesture {
                                        openURL(result.url)
                                    }
                            }
                        }
                        .padding()
                    }
                } else {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "globe")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Search the Web")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Find book reviews, author news, and literary content from trusted sources")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        // Web badge
                        HStack {
                            Image(systemName: "network")
                            Text("Web")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(in: Capsule())
                    }
                    
                    Spacer()
                }
                
                // Error display
                if let error = searchService.searchError {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Web Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await searchService.clearExpiredCache(modelContext: modelContext)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
            Button("Settings") {
                // Navigate to settings
                NotificationCenter.default.post(name: Notification.Name("ShowSettings"), object: nil)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please configure your Perplexity API key in Settings to use web search.")
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        isFirstSearch = false
        
        Task {
            do {
                switch selectedSearchType {
                case .books:
                    searchResults = try await searchService.searchBooks(
                        query: searchQuery,
                        modelContext: modelContext
                    )
                case .trending:
                    searchResults = try await searchService.searchTrending(
                        query: searchQuery.isEmpty ? "bestseller books" : searchQuery,
                        modelContext: modelContext
                    )
                case .general:
                    searchResults = try await searchService.searchGeneral(
                        query: searchQuery,
                        modelContext: modelContext
                    )
                }
            } catch PerplexitySearchError.missingAPIKey {
                showingAPIKeyAlert = true
            } catch {
                searchService.searchError = error
            }
        }
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with link icon
            HStack(alignment: .top) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Snippet
            if !result.snippet.isEmpty {
                Text(result.snippet)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // URL and date
            HStack {
                Text(URL(string: result.url)?.host ?? result.url)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                if let displayDate = result.displayDate {
                    Text(displayDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if result.isRecent {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview
#Preview {
    WebSearchView()
        .preferredColorScheme(.dark)
}