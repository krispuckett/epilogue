# AI Services Integration

## Overview
Connected UnifiedChatView to AI services with support for multiple providers, starting with Perplexity and preparing for future Apple Intelligence integration.

## Architecture

### 1. AICompanionService (New)
Central service that manages AI providers and handles message processing:
- **Singleton pattern** for consistent state across the app
- **Provider abstraction** to support multiple AI services
- **Conversation context** management for better responses
- **Configuration checking** to ensure services are properly set up

### 2. AI Providers
Currently supported:
- **Perplexity**: Fully implemented with streaming support
- **Apple Intelligence**: Placeholder for future implementation

### 3. Integration Points

#### UnifiedChatView Updates:
```swift
private func getAIResponse(for userInput: String) async {
    let aiService = AICompanionService.shared
    
    // Check configuration
    guard aiService.isConfigured() else {
        // Show configuration message
        return
    }
    
    // Get response with conversation context
    let response = try await aiService.processMessage(
        userInput,
        bookContext: currentBookContext,
        conversationHistory: messages
    )
}
```

## Features

### 1. Conversation Context
- Includes book context in prompts when discussing a specific book
- Maintains conversation history (last 3 exchanges) for continuity
- Builds contextual prompts for more relevant responses

### 2. Error Handling
- Configuration checking before API calls
- User-friendly error messages
- Fallback messages for unconfigured services

### 3. Provider Management
- Easy switching between AI providers
- Persistent provider preference
- Configuration status checking

### 4. Settings UI
- New AISettingsView for managing providers
- API key configuration instructions
- Visual status indicators

## Configuration

### Perplexity Setup:
1. Get API key from perplexity.ai/settings/api
2. Add to Info.plist: `PERPLEXITY_API_KEY = "your-key-here"`
3. The service will automatically detect and use the key

### Future Apple Intelligence:
- Will use on-device processing (no API key required)
- Automatic availability detection
- Seamless switching when available

## Benefits
1. **Flexibility**: Easy to switch between AI providers
2. **Context-Aware**: Responses consider book context and conversation history
3. **User-Friendly**: Clear configuration instructions and error messages
4. **Future-Proof**: Ready for Apple Intelligence integration
5. **Secure**: API keys stored locally, never transmitted except to the service

## Usage
The chat now provides intelligent responses about books, with context from:
- Current book being discussed
- Recent conversation history
- Literary-focused system prompts