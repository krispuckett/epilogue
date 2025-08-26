# Secure API Key Setup for Epilogue

## Important Security Notice
**NEVER commit API keys to version control!** This app uses iOS Keychain for secure API key storage.

## Initial Setup

### 1. Build Configuration
The `Config.xcconfig` file is for build configuration only and should NOT contain actual API keys:
- Copy `Config.xcconfig.template` to `Config.xcconfig` (if not already done)
- Leave the `PERPLEXITY_API_KEY` field empty
- The app will use Keychain for secure storage

### 2. First Launch
When you first launch the app:
1. The app will detect no API key is configured
2. You'll be prompted to enter your API key
3. Navigate to Settings > AI & Intelligence > API Configuration
4. Enter your Perplexity API key (starts with `pplx-`)
5. The key will be securely stored in iOS Keychain

### 3. Get Your API Key
1. Visit https://www.perplexity.ai/settings/api
2. Sign in to your Perplexity account
3. Generate a new API key
4. Copy the key (it starts with `pplx-`)

## Security Features

### ✅ What We Do
- Store API keys in iOS Keychain (encrypted)
- Validate API key format before storage
- Use HTTPS for all API communications
- Clear API key from memory after use
- No API keys in source code or config files

### ❌ What We Don't Do
- Store API keys in Info.plist
- Store API keys in UserDefaults
- Store API keys in plain text files
- Log API keys to console
- Include API keys in crash reports

## Rotating Your API Key

If you need to change your API key:
1. Go to Settings > AI & Intelligence > API Configuration
2. Enter your new API key
3. The old key will be replaced
4. Consider rotating keys regularly for security

## Troubleshooting

### API Key Not Working
1. Verify the key starts with `pplx-`
2. Check for extra spaces or characters
3. Ensure the key hasn't expired
4. Try generating a new key from Perplexity

### Key Not Persisting
1. Check iOS Settings > Epilogue > Keychain Access is enabled
2. Ensure sufficient device storage
3. Try removing and re-adding the key

## Developer Notes

### Testing Without API Key
The app includes fallback behavior when no API key is configured:
- Chat features will show an informative message
- Other features continue to work normally
- No crashes or data loss

### Security Audit Checklist
- [ ] Config.xcconfig has no actual API key
- [ ] Info.plist has no API key reference
- [ ] All services use KeychainManager
- [ ] No hardcoded API keys in source
- [ ] API key validation before storage

## Migration from Old Version

If upgrading from a version that stored keys insecurely:
1. The app will NOT migrate keys automatically (for security)
2. You must manually enter your key in Settings
3. Old storage locations are ignored
4. This is a one-time setup after upgrading

## Contact

For security concerns or questions about API key handling:
- File an issue (do NOT include your API key)
- Use the in-app feedback (Settings > Help & Feedback)