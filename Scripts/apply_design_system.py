#!/usr/bin/env python3
"""
Apply Design System updates to all Swift files in the Epilogue project.
This script standardizes colors, opacity values, corner radius, padding, and animations.
"""

import os
import re
import sys
from pathlib import Path

# Base directory
BASE_DIR = "/Users/kris/Epilogue/Epilogue/Epilogue"

# Color replacements
COLOR_REPLACEMENTS = [
    (r'Color\(red: 1\.0, green: 0\.55, blue: 0\.26\)', 'DesignSystem.Colors.primaryAccent'),
    (r'Color\(red: 0\.11, green: 0\.105, blue: 0\.102\)', 'DesignSystem.Colors.surfaceBackground'),
    (r'\.white\.opacity\(0\.7\d*\)', 'DesignSystem.Colors.textSecondary'),
    (r'\.white\.opacity\(0\.5\d*\)', 'DesignSystem.Colors.textTertiary'),
    (r'\.white\.opacity\(0\.3\d*\)', 'DesignSystem.Colors.textQuaternary'),
    (r'Color\.white\.opacity\(0\.7\d*\)', 'DesignSystem.Colors.textSecondary'),
    (r'Color\.white\.opacity\(0\.5\d*\)', 'DesignSystem.Colors.textTertiary'),
    (r'Color\.white\.opacity\(0\.3\d*\)', 'DesignSystem.Colors.textQuaternary'),
]

# Opacity standardization (to 0.05 increments)
OPACITY_REPLACEMENTS = [
    (r'\.opacity\(0\.03\)', '.opacity(0.05)'),
    (r'\.opacity\(0\.04\)', '.opacity(0.05)'),
    (r'\.opacity\(0\.06\)', '.opacity(0.05)'),
    (r'\.opacity\(0\.07\)', '.opacity(0.05)'),
    (r'\.opacity\(0\.08\)', '.opacity(0.10)'),
    (r'\.opacity\(0\.09\)', '.opacity(0.10)'),
    (r'\.opacity\(0\.12\)', '.opacity(0.10)'),
    (r'\.opacity\(0\.13\)', '.opacity(0.15)'),
    (r'\.opacity\(0\.14\)', '.opacity(0.15)'),
    (r'\.opacity\(0\.16\)', '.opacity(0.15)'),
    (r'\.opacity\(0\.17\)', '.opacity(0.15)'),
    (r'\.opacity\(0\.18\)', '.opacity(0.20)'),
    (r'\.opacity\(0\.19\)', '.opacity(0.20)'),
    (r'\.opacity\(0\.22\)', '.opacity(0.20)'),
    (r'\.opacity\(0\.23\)', '.opacity(0.25)'),
    (r'\.opacity\(0\.24\)', '.opacity(0.25)'),
    (r'\.opacity\(0\.26\)', '.opacity(0.25)'),
    (r'\.opacity\(0\.27\)', '.opacity(0.25)'),
    (r'\.opacity\(0\.28\)', '.opacity(0.30)'),
    (r'\.opacity\(0\.29\)', '.opacity(0.30)'),
    (r'\.opacity\(0\.32\)', '.opacity(0.30)'),
    (r'\.opacity\(0\.33\)', '.opacity(0.35)'),
    (r'\.opacity\(0\.34\)', '.opacity(0.35)'),
    (r'\.opacity\(0\.36\)', '.opacity(0.35)'),
    (r'\.opacity\(0\.37\)', '.opacity(0.35)'),
    (r'\.opacity\(0\.38\)', '.opacity(0.40)'),
    (r'\.opacity\(0\.39\)', '.opacity(0.40)'),
    (r'\.opacity\(0\.42\)', '.opacity(0.40)'),
    (r'\.opacity\(0\.43\)', '.opacity(0.45)'),
    (r'\.opacity\(0\.44\)', '.opacity(0.45)'),
    (r'\.opacity\(0\.46\)', '.opacity(0.45)'),
    (r'\.opacity\(0\.47\)', '.opacity(0.45)'),
    (r'\.opacity\(0\.48\)', '.opacity(0.50)'),
    (r'\.opacity\(0\.49\)', '.opacity(0.50)'),
    (r'\.opacity\(0\.52\)', '.opacity(0.50)'),
    (r'\.opacity\(0\.53\)', '.opacity(0.55)'),
    (r'\.opacity\(0\.54\)', '.opacity(0.55)'),
    (r'\.opacity\(0\.56\)', '.opacity(0.55)'),
    (r'\.opacity\(0\.57\)', '.opacity(0.55)'),
    (r'\.opacity\(0\.58\)', '.opacity(0.60)'),
    (r'\.opacity\(0\.59\)', '.opacity(0.60)'),
    (r'\.opacity\(0\.62\)', '.opacity(0.60)'),
    (r'\.opacity\(0\.63\)', '.opacity(0.65)'),
    (r'\.opacity\(0\.64\)', '.opacity(0.65)'),
    (r'\.opacity\(0\.66\)', '.opacity(0.65)'),
    (r'\.opacity\(0\.67\)', '.opacity(0.65)'),
    (r'\.opacity\(0\.68\)', '.opacity(0.70)'),
    (r'\.opacity\(0\.69\)', '.opacity(0.70)'),
    (r'\.opacity\(0\.72\)', '.opacity(0.70)'),
    (r'\.opacity\(0\.73\)', '.opacity(0.75)'),
    (r'\.opacity\(0\.74\)', '.opacity(0.75)'),
    (r'\.opacity\(0\.76\)', '.opacity(0.75)'),
    (r'\.opacity\(0\.77\)', '.opacity(0.75)'),
    (r'\.opacity\(0\.78\)', '.opacity(0.80)'),
    (r'\.opacity\(0\.79\)', '.opacity(0.80)'),
    (r'\.opacity\(0\.82\)', '.opacity(0.80)'),
    (r'\.opacity\(0\.83\)', '.opacity(0.85)'),
    (r'\.opacity\(0\.84\)', '.opacity(0.85)'),
    (r'\.opacity\(0\.86\)', '.opacity(0.85)'),
    (r'\.opacity\(0\.87\)', '.opacity(0.85)'),
    (r'\.opacity\(0\.88\)', '.opacity(0.90)'),
    (r'\.opacity\(0\.89\)', '.opacity(0.90)'),
    (r'\.opacity\(0\.92\)', '.opacity(0.90)'),
    (r'\.opacity\(0\.93\)', '.opacity(0.95)'),
    (r'\.opacity\(0\.94\)', '.opacity(0.95)'),
    (r'\.opacity\(0\.96\)', '.opacity(0.95)'),
    (r'\.opacity\(0\.97\)', '.opacity(0.95)'),
    (r'\.opacity\(0\.98\)', '.opacity(1.0)'),
    (r'\.opacity\(0\.99\)', '.opacity(1.0)'),
]

# Corner radius standardization
CORNER_RADIUS_REPLACEMENTS = [
    (r'cornerRadius:\s*14', 'cornerRadius: DesignSystem.CornerRadius.card'),
    (r'cornerRadius:\s*16', 'cornerRadius: DesignSystem.CornerRadius.card'),
    (r'cornerRadius:\s*18', 'cornerRadius: DesignSystem.CornerRadius.card'),
    (r'cornerRadius:\s*20', 'cornerRadius: DesignSystem.CornerRadius.large'),
    (r'cornerRadius:\s*10', 'cornerRadius: DesignSystem.CornerRadius.medium'),
    (r'cornerRadius:\s*12', 'cornerRadius: DesignSystem.CornerRadius.medium'),
    (r'cornerRadius:\s*8', 'cornerRadius: DesignSystem.CornerRadius.small'),
    (r'cornerRadius:\s*6', 'cornerRadius: DesignSystem.CornerRadius.small'),
]

# Animation standardization
ANIMATION_REPLACEMENTS = [
    (r'\.spring\(response:\s*0\.3,\s*dampingFraction:\s*0\.[678]\)', 'DesignSystem.Animation.springStandard'),
    (r'\.spring\(response:\s*0\.3,\s*dampingFraction:\s*0\.8\)', 'DesignSystem.Animation.springStandard'),
    (r'\.spring\(response:\s*0\.4,\s*dampingFraction:\s*0\.8[05]\)', 'DesignSystem.Animation.springSmooth'),
    (r'\.spring\(response:\s*0\.2,\s*dampingFraction:\s*0\.[78]\)', 'DesignSystem.Animation.springQuick'),
    (r'\.easeInOut\(duration:\s*0\.2\)', 'DesignSystem.Animation.easeQuick'),
    (r'\.easeInOut\(duration:\s*0\.3\)', 'DesignSystem.Animation.easeStandard'),
]

# Haptic feedback standardization
HAPTIC_REPLACEMENTS = [
    (r'HapticManager\.shared\.lightTap\(\)', 'DesignSystem.HapticFeedback.light()'),
    (r'HapticManager\.shared\.mediumTap\(\)', 'DesignSystem.HapticFeedback.medium()'),
    (r'HapticManager\.shared\.success\(\)', 'DesignSystem.HapticFeedback.success()'),
    (r'HapticManager\.shared\.warning\(\)', 'DesignSystem.HapticFeedback.warning()'),
    (r'HapticManager\.shared\.selectionChanged\(\)', 'DesignSystem.HapticFeedback.selection()'),
]

# Padding standardization
PADDING_REPLACEMENTS = [
    (r'\.padding\(24\)', '.padding(DesignSystem.Spacing.cardPadding)'),
    (r'\.padding\(16\)', '.padding(DesignSystem.Spacing.inlinePadding)'),
    (r'\.padding\(20\)', '.padding(DesignSystem.Spacing.listItemPadding)'),
    (r'\.padding\(\.horizontal,\s*24\)', '.padding(.horizontal, DesignSystem.Spacing.cardPadding)'),
    (r'\.padding\(\.horizontal,\s*16\)', '.padding(.horizontal, DesignSystem.Spacing.inlinePadding)'),
    (r'\.padding\(\.horizontal,\s*20\)', '.padding(.horizontal, DesignSystem.Spacing.listItemPadding)'),
]

def process_file(filepath):
    """Process a single Swift file."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original_content = content
        
        # Apply all replacements
        for pattern, replacement in COLOR_REPLACEMENTS:
            content = re.sub(pattern, replacement, content)
        
        for pattern, replacement in OPACITY_REPLACEMENTS:
            content = re.sub(pattern, replacement, content)
        
        for pattern, replacement in CORNER_RADIUS_REPLACEMENTS:
            content = re.sub(pattern, replacement, content)
        
        for pattern, replacement in ANIMATION_REPLACEMENTS:
            content = re.sub(pattern, replacement, content)
        
        for pattern, replacement in HAPTIC_REPLACEMENTS:
            content = re.sub(pattern, replacement, content)
        
        for pattern, replacement in PADDING_REPLACEMENTS:
            content = re.sub(pattern, replacement, content)
        
        # Check if file was modified
        if content != original_content:
            # Add import if not present and file was modified
            if 'import SwiftUI' in content and 'DesignSystem' not in content:
                # Add import after SwiftUI import
                content = content.replace('import SwiftUI', 'import SwiftUI\nimport DesignSystem', 1)
            
            # Save the modified content
            with open(filepath, 'w') as f:
                f.write(content)
            
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Main function to process all Swift files."""
    print("🎨 Applying Design System updates...")
    print(f"📁 Base directory: {BASE_DIR}")
    
    # Find all Swift files
    swift_files = []
    for root, dirs, files in os.walk(BASE_DIR):
        # Skip certain directories
        if 'DesignSystem.swift' in root:
            continue
        if '.build' in root or 'DerivedData' in root:
            continue
        
        for file in files:
            if file.endswith('.swift'):
                swift_files.append(os.path.join(root, file))
    
    print(f"📝 Found {len(swift_files)} Swift files")
    
    modified_count = 0
    for filepath in swift_files:
        if process_file(filepath):
            modified_count += 1
            print(f"✅ Updated: {os.path.relpath(filepath, BASE_DIR)}")
    
    print(f"\n✨ Complete! Modified {modified_count} files")

if __name__ == "__main__":
    main()