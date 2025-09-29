# Background Tasks Configuration Required

To enable background refresh for trending books, the following needs to be added to Info.plist:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.epilogue.trending.refresh</string>
</array>
```

Also, "fetch" should be added to UIBackgroundModes:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>fetch</string>
</array>
```

This will allow the EnhancedTrendingBooksService to refresh trending books in the background twice monthly.