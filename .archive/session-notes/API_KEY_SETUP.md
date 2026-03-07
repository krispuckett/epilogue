# Setting up Perplexity API Key for Epilogue

## Quick Setup

1. **Get your Perplexity API Key**
   - Go to https://www.perplexity.ai/settings/api
   - Create an account if needed
   - Generate a new API key

2. **Add to Info.plist**
   - Open `Epilogue/Info.plist` in Xcode
   - Add a new row with:
     - Key: `PERPLEXITY_API_KEY`
     - Type: `String`
     - Value: Your actual API key (e.g., `pplx-xxxxxxxxxxxx`)

3. **Clean and Rebuild**
   - In Xcode: Product → Clean Build Folder (⌘⇧K)
   - Build and run the app

## Alternative: Using Config.xcconfig (Recommended for Security)

1. **Create Config.xcconfig file**
   ```
   // Config.xcconfig
   PERPLEXITY_API_KEY = pplx-your-actual-api-key-here
   ```

2. **Add to .gitignore**
   ```
   Config.xcconfig
   ```

3. **Configure project to use Config.xcconfig**
   - Select your project in Xcode
   - Go to project settings → Info tab
   - Under Configurations, set Debug and Release to use Config.xcconfig

4. **Update Info.plist**
   ```xml
   <key>PERPLEXITY_API_KEY</key>
   <string>$(PERPLEXITY_API_KEY)</string>
   ```

## Troubleshooting

- Make sure the API key doesn't contain placeholder text like "your_actual_api_key_here"
- Ensure the key starts with "pplx-" (Perplexity's key format)
- Clean build folder after adding the key
- Check console output for initialization messages

## Security Note

Never commit your actual API key to version control. Use the Config.xcconfig approach for better security.