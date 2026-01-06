# Chips App Logo

A CPU chip-inspired logo with a pressable button effect.

## Usage

### In SwiftUI Views

```swift
import SwiftUI

// Static logo
ChipLogoView(size: 100, style: .appIcon)

// Pressable logo with animation
PressableChipLogoView(size: 100, style: .appIcon) {
    print("Logo pressed!")
}
```

### Logo Styles

- `.appIcon` - Simplified version optimized for app icons (4 pins, 2 circuit lines)
- `.inline` - Medium detail for inline UI use (5 pins, 3 circuit lines)
- `.detailed` - Most detailed version (6 pins, 4 circuit lines)

### Features

- **3D Button Effect**: Gradient fills and shadows create a pressable button appearance
- **Press Animation**: `PressableChipLogoView` includes spring animation on tap
- **CPU Chip Design**: Features pins, circuit patterns, and a central core
- **Scalable**: Works at any size from 16x16 to 1024x1024

## Generating App Icon Assets

To generate PNG images for app icons:

1. Open the app in Xcode
2. Use the `LogoGenerator` utility (or create a simple script)
3. Export at sizes: 16, 32, 64, 128, 256, 512, 1024

The logo is designed to work well at all sizes, with detail level automatically adjusting based on the `style` parameter.

## Design Notes

- **Color Scheme**: Blue gradient chip on light gray button base
- **Shadows**: Creates depth and pressability
- **Pins**: Represent the connection points of a CPU chip
- **Circuit Pattern**: Grid lines suggest the internal structure
- **Center Dot**: Represents the CPU core

## Customization

You can customize colors, sizes, and details by modifying `ChipLogoView.swift`. The component is fully SwiftUI-based and can be easily adapted to match your brand colors.

