# TestFlight & App Store Connect Checklist for Epilogue

## ✅ Completed Features
- [x] Daily Perplexity quota system (10 questions/day)
- [x] Quota exceeded graceful UI
- [x] Gandalf mode for unlimited testing
- [x] Delete all data functionality fixed
- [x] Privacy permissions in Info.plist

## 📱 App Configuration Required

### 1. Version & Build Numbers
- [ ] Set Marketing Version (e.g., 1.0.0)
- [ ] Set Build Number (e.g., 1)
- [ ] Update in Xcode project settings

### 2. App Capabilities & Entitlements
- [x] Camera Usage - Book scanning
- [x] Photo Library - Custom covers
- [x] Microphone Usage - Voice notes
- [x] Visual Intelligence - Text extraction
- [ ] Push Notifications (if needed)

### 3. Required Info.plist Keys
- [x] NSCameraUsageDescription
- [x] NSPhotoLibraryUsageDescription
- [x] NSMicrophoneUsageDescription
- [x] NSVisualIntelligenceUsageDescription
- [ ] ITSAppUsesNonExemptEncryption (set to NO if no encryption)

### 4. App Icons & Assets
- [ ] App Icon (1024x1024) for App Store
- [ ] All required app icon sizes
- [ ] Launch Screen configured
- [ ] Screenshots for each device size

### 5. Privacy & Legal
- [x] Privacy Policy URL (https://readepilogue.com/privacy)
- [x] Terms of Service URL (https://readepilogue.com/terms)
- [ ] Add URLs to App Store Connect

## 🚀 TestFlight Specific

### 1. Build Configuration
- [ ] Archive build in Release mode
- [ ] Code signing with distribution certificate
- [ ] Provisioning profile configured

### 2. TestFlight Information
- [ ] Test Information (What to test)
- [ ] Beta App Description
- [ ] Contact Email
- [ ] Marketing URL (optional)

### 3. Beta Testing Groups
- [ ] Internal Testing Group
- [ ] External Testing Group (up to 10,000 testers)
- [ ] TestFlight Public Link (optional)

## 📝 App Store Connect Metadata

### Required Information:
1. **App Name**: Epilogue
2. **Subtitle**: Your ambient reading companion
3. **Primary Category**: Books or Education
4. **Secondary Category**: Productivity

### Description (Draft):
```
Epilogue transforms your reading experience with ambient intelligence. Capture quotes, ask questions, and reflect on your books with AI-powered insights.

KEY FEATURES:
• Ambient Reading Mode - Voice-first interaction while you read
• Smart Book Scanner - Add books instantly with camera or ISBN
• AI Assistant - Ask questions about your books with Perplexity integration
• Beautiful Notes - Capture quotes, thoughts, and questions
• Liquid Glass UI - Stunning iOS 26 design with adaptive themes

TESTFLIGHT BETA:
During beta, AI questions are limited to 10 per day to manage costs. Thank you for helping us test!

Built with soul in Denver, CO.
```

### Keywords:
- reading
- books
- notes
- quotes
- AI assistant
- ambient
- voice notes
- book scanner
- reading companion
- book tracker

### What's New (v1.0):
```
Initial TestFlight release
• Ambient reading mode
• Book scanner
• AI-powered questions
• Note capture
• Beautiful iOS 26 design
```

## 🔧 Technical Requirements

### Minimum Requirements:
- iOS 26.0 or later
- iPhone only (for now)
- ~50MB download size

### Supported Devices:
- iPhone 15 and later (optimized)
- All devices running iOS 26

## 🐛 Known Issues for TestFlight

1. **Daily Quota**: 10 Perplexity questions per day (use Gandalf mode to bypass)
2. **Performance**: Some gradient animations may lag on older devices
3. **Scanner**: Book scanner works best in good lighting

## 📊 TestFlight Test Points

Ask testers to specifically test:
1. Book scanning (covers and ISBNs)
2. Ambient mode voice recording
3. AI question accuracy
4. Note capture and organization
5. Performance on different devices
6. Dark mode compatibility

## 🎯 Pre-Submission Checklist

- [ ] Test on real device
- [ ] Test all critical paths
- [ ] Verify no crashes in Release mode
- [ ] Remove all debug code
- [ ] Ensure no placeholder content
- [ ] Test quota system works
- [ ] Verify scanner permissions
- [ ] Check all URLs work
- [ ] Test "Delete All Data"
- [ ] Verify Gandalf mode hidden

## 📅 Timeline

1. **Today**: Prepare build for TestFlight
2. **Upload**: Archive and upload to App Store Connect
3. **Review**: Apple review (24-48 hours for TestFlight)
4. **Beta Test**: 2-4 weeks of testing
5. **App Store**: Submit final version after beta

## 🚨 Important Notes

- TestFlight builds expire after 90 days
- Can have up to 100 internal testers (immediate)
- Up to 10,000 external testers (after Apple review)
- Collect crash reports and feedback through TestFlight
- Use TestFlight feedback to improve before App Store submission

---

Remember: This is a beta! Expect bugs, gather feedback, and iterate quickly.