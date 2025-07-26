# Exporting Glass Icons for Navigation Bar

## File Names and Sizes Needed

### Book Icon (glass-book-open)
- `glass-book-open.png` - 24×24px
- `glass-book-open@2x.png` - 48×48px
- `glass-book-open@3x.png` - 72×72px

### Feather Icon (glass-feather)
- `glass-feather.png` - 24×24px
- `glass-feather@2x.png` - 48×48px
- `glass-feather@3x.png` - 72×72px

### Messages Icon (glass-msgs)
- `glass-msgs.png` - 24×24px
- `glass-msgs@2x.png` - 48×48px
- `glass-msgs@3x.png` - 72×72px

## Export Settings

1. **Format**: PNG
2. **Background**: Transparent
3. **Color Profile**: sRGB
4. **Include**: All effects (gradients, shadows, glass effects)

## Where to Place Files

Place the exported PNG files in these directories:
- `/Users/kris/Epilogue/Epilogue/Epilogue/Assets.xcassets/glass-book-open.imageset/`
- `/Users/kris/Epilogue/Epilogue/Epilogue/Assets.xcassets/glass-feather.imageset/`
- `/Users/kris/Epilogue/Epilogue/Epilogue/Assets.xcassets/glass-msgs.imageset/`

## Converting SVG to PNG

### Option 1: Using a Design Tool (Figma, Sketch, etc.)
1. Import your SVG files
2. Set artboard to required size
3. Export as PNG at 1x, 2x, and 3x

### Option 2: Using Command Line (ImageMagick)
```bash
# Install ImageMagick if needed
brew install imagemagick

# Convert SVG to PNG at different sizes
convert 24-book-open.svg -resize 24x24 glass-book-open.png
convert 24-book-open.svg -resize 48x48 glass-book-open@2x.png
convert 24-book-open.svg -resize 72x72 glass-book-open@3x.png
```

### Option 3: Using Online Converter
- CloudConvert: https://cloudconvert.com/svg-to-png
- Convertio: https://convertio.co/svg-png/

## Important Notes

1. The glass effects with gradients (#ff8c42) will be preserved
2. Tab bar will overlay a tint when selected, but glass effects remain visible
3. Make sure to maintain transparent backgrounds
4. Test on both light and dark modes

## Once Files Are Ready

The app is already configured to use these icons. Just place the PNG files in the correct folders and rebuild.