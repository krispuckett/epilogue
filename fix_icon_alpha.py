#!/usr/bin/env python3
"""
Remove alpha channel from app icon for App Store submission.
Replaces transparency with white background.
"""

from PIL import Image
import sys
import os

def remove_alpha(input_path, output_path):
    """Remove alpha channel from PNG image."""

    # Open the image
    img = Image.open(input_path)

    # Check if image has alpha channel
    if img.mode in ('RGBA', 'LA'):
        # Create a white background
        background = Image.new('RGB', img.size, (255, 255, 255))

        # Paste the image on the white background
        # This handles transparency properly
        if img.mode == 'RGBA':
            background.paste(img, mask=img.split()[3])  # Use alpha channel as mask
        else:
            background.paste(img, mask=img.split()[1])  # LA mode

        # Save without alpha
        background.save(output_path, 'PNG', optimize=True, quality=100)
        print(f"✅ Removed alpha channel from {input_path}")
        print(f"   Saved to: {output_path}")
    else:
        # No alpha channel, just copy
        img.save(output_path, 'PNG', optimize=True, quality=100)
        print(f"ℹ️ Image has no alpha channel, copied to {output_path}")

if __name__ == "__main__":
    icon_dir = "/Users/kris/Epilogue/Epilogue/Epilogue/Assets.xcassets/AppIcon.appiconset"
    input_file = os.path.join(icon_dir, "AppIcon-1024-original.png")
    output_file = os.path.join(icon_dir, "AppIcon-1024.png")

    if not os.path.exists(input_file):
        print(f"❌ Error: {input_file} not found")
        sys.exit(1)

    try:
        remove_alpha(input_file, output_file)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)