# Epilogue API Key Configuration Guide

## Current Configuration Flow

Your Perplexity API key is currently configured and working through the following system:

### 1. Development Configuration (Current Setup)
- **Config.xcconfig**: Contains your actual API key
- **Info.plist**: References the key using `$(PERPLEXITY_API_KEY)`
- **Status**: ✅ Working - You can continue using this for development

### 2. Settings UI Configuration (For TestFlight/Production)
When you're ready for TestFlight:
1. Go to Settings → AI & Intelligence → Perplexity → API Key
2. Enter your API key there
3. The key will be securely stored in the iOS Keychain
4. This takes priority over the Config.xcconfig method

### How the App Loads the API Key

The PerplexityService checks in this order:
1. **First**: KeychainManager (from Settings UI)
2. **Fallback**: Info.plist (from Config.xcconfig)

```swift
// From PerplexityService.swift
let apiKey = KeychainManager.shared.getPerplexityAPIKey() ?? 
             Bundle.main.object(forInfoDictionaryKey: "PERPLEXITY_API_KEY") as? String
```

### Current Status
- ✅ Config.xcconfig has your API key
- ✅ Info.plist is properly configured
- ✅ PerplexityService will load from Config.xcconfig
- ✅ Settings UI is ready for when you need it

### For TestFlight Distribution
Before submitting to TestFlight:
1. Remove the API key from Config.xcconfig (or don't include it in the build)
2. Users will need to add their own API key through Settings
3. The app will guide them to configure it on first launch

### Security Notes
- Config.xcconfig should never be committed to version control
- The Settings UI stores keys in the secure iOS Keychain
- Keys are encrypted and only accessible by your app