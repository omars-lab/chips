#!/usr/bin/env swift
// Generate app icon and in-app logo images from ChipLogoView
// Usage: swift scripts/generate-logo.swift <output_dir>

import SwiftUI
import AppKit
import Foundation

// Copy of ChipLogoView for standalone generation
struct ChipLogoView: View {
    let size: CGFloat
    let isPressed: Bool
    
    init(size: CGFloat = 100, isPressed: Bool = false) {
        self.size = size
        self.isPressed = isPressed
    }
    
    var body: some View {
        ZStack {
            // Stacked poker chips
            stackedChipsView
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.95 : 1.0)
    }
    
    // Number of chips in the stack
    private var chipCount: Int {
        3
    }
    
    // Chip dimensions - making chips more visible and circular
    private var chipDiameter: CGFloat {
        size * 0.75
    }
    
    private var chipThickness: CGFloat {
        size * 0.15  // Thicker chips for better visibility
    }
    
    private var chipCornerRadius: CGFloat {
        chipThickness * 0.5
    }
    
    // Offset between stacked chips - more pronounced
    private var chipOffset: CGFloat {
        size * 0.12  // More offset for clearer stacking
    }
    
    // Chip colors (poker chip colors) - more vibrant
    private var chipColors: [(top: Color, middle: Color, bottom: Color, rim: Color)] {
        [
            // Red chip
            (Color(red: 0.9, green: 0.2, blue: 0.2),
             Color(red: 0.8, green: 0.15, blue: 0.15),
             Color(red: 0.7, green: 0.1, blue: 0.1),
             Color(red: 0.95, green: 0.3, blue: 0.3)),
            // Blue chip
            (Color(red: 0.2, green: 0.4, blue: 0.9),
             Color(red: 0.15, green: 0.35, blue: 0.8),
             Color(red: 0.1, green: 0.3, blue: 0.7),
             Color(red: 0.3, green: 0.5, blue: 0.95)),
            // Green chip
            (Color(red: 0.2, green: 0.7, blue: 0.3),
             Color(red: 0.15, green: 0.6, blue: 0.25),
             Color(red: 0.1, green: 0.5, blue: 0.2),
             Color(red: 0.3, green: 0.8, blue: 0.4))
        ]
    }
    
    @ViewBuilder
    private var stackedChipsView: some View {
        ZStack {
            // Draw chips from bottom to top
            ForEach(0..<chipCount, id: \.self) { index in
                let chipIndex = chipCount - 1 - index // Reverse order for proper stacking
                let colors = chipColors[min(chipIndex, chipColors.count - 1)]
                let offset = CGFloat(chipIndex) * chipOffset
                
                pokerChipView(
                    colors: colors,
                    offset: offset,
                    isTopChip: chipIndex == chipCount - 1,
                    zIndex: Double(chipIndex)
                )
            }
        }
    }
    
    @ViewBuilder
    private func pokerChipView(colors: (top: Color, middle: Color, bottom: Color, rim: Color), offset: CGFloat, isTopChip: Bool, zIndex: Double) -> some View {
        ZStack {
            // Main chip body - circular with 3D effect
            ZStack {
                // Bottom shadow layer
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [colors.bottom, colors.bottom.opacity(0.8)],
                            center: .center,
                            startRadius: chipDiameter * 0.3,
                            endRadius: chipDiameter * 0.5
                        )
                    )
                    .frame(width: chipDiameter, height: chipThickness)
                    .offset(y: chipThickness * 0.3)
                
                // Main chip body with gradient
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [colors.top, colors.middle, colors.bottom],
                            center: UnitPoint(x: 0.3, y: 0.3),
                            startRadius: 0,
                            endRadius: chipDiameter * 0.5
                        )
                    )
                    .frame(width: chipDiameter, height: chipThickness)
                    .overlay(
                        // Rim/edge highlight
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        colors.rim.opacity(0.8),
                                        colors.rim.opacity(0.3),
                                        Color.black.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.3),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                
                // Inner circle border (poker chip characteristic)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: chipDiameter * 0.75, height: chipDiameter * 0.75)
                
                // Smart chip icon on top chip only
                if isTopChip {
                    smartChipIcon
                        .frame(width: chipDiameter * 0.45, height: chipDiameter * 0.45)
                }
            }
        }
        .offset(y: offset)
        .zIndex(zIndex)
    }
    
    @ViewBuilder
    private var smartChipIcon: some View {
        ZStack {
            // Chip base - more visible
            RoundedRectangle(cornerRadius: size * 0.025)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.4, blue: 0.9),
                            Color(red: 0.05, green: 0.3, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.025)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            // Circuit pattern - more visible
            ZStack {
                // Horizontal lines
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: size * 0.08, height: size * 0.008)
                        Spacer()
                    }
                }
                
                // Vertical lines
                VStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: size * 0.008, height: size * 0.08)
                        Spacer()
                    }
                }
                
                // Center dot (CPU core) - more prominent
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.4)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.03
                        )
                    )
                    .frame(width: size * 0.06, height: size * 0.06)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                    )
            }
            .frame(width: size * 0.28, height: size * 0.28)
        }
    }
}

// Generate app icons
// macOS requires: 16, 32, 128, 256, 512 (both 1x and 2x)
// iOS requires: 1024x1024 (single)
let macIconSizes: [(size: CGFloat, scale: CGFloat)] = [
    (16, 1.0), (16, 2.0),
    (32, 1.0), (32, 2.0),
    (128, 1.0), (128, 2.0),
    (256, 1.0), (256, 2.0),
    (512, 1.0), (512, 2.0)
]
let iosIconSize: CGFloat = 1024
let appLogoSizes: [CGFloat] = [40, 60, 80, 120, 180, 240]

guard CommandLine.arguments.count >= 2 else {
    print("❌ Usage: swift scripts/generate-logo.swift <output_dir>")
    exit(1)
}

let outputBaseDir = CommandLine.arguments[1]
let appIconsDir = "\(outputBaseDir)/app-icons"
let appLogosDir = "\(outputBaseDir)/app-logos"

// Helper function to render on MainActor
func renderIcon(size: CGFloat, scale: CGFloat, outputPath: String) -> Bool {
    var success = false
    let semaphore = DispatchSemaphore(value: 0)
    
    Task { @MainActor in
        defer { semaphore.signal() }
        let view = ChipLogoView(size: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        
        #if os(macOS)
        if let nsImage = renderer.nsImage {
            let url = URL(fileURLWithPath: outputPath)
            if let tiffData = nsImage.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
                success = true
            }
        }
        #endif
    }
    
    // Wait with timeout and process run loop
    let timeout = DispatchTime.now() + .seconds(5)
    while semaphore.wait(timeout: .now() + .milliseconds(100)) == .timedOut {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        if DispatchTime.now() > timeout {
            print("  ⚠️ Timeout rendering icon")
            return false
        }
    }
    return success
}

print("📱 Generating macOS app icons...")
for iconSpec in macIconSizes {
    let size = iconSpec.size
    let scale = iconSpec.scale
    let scaleSuffix = scale == 2.0 ? "@2x" : ""
    let imageName = "icon_\(Int(size))x\(Int(size))\(scaleSuffix).png"
    let url = URL(fileURLWithPath: appIconsDir).appendingPathComponent(imageName)
    
    if renderIcon(size: size, scale: scale, outputPath: url.path) {
        print("  ✅ \(imageName)")
    }
}

print("\n📱 Generating iOS app icon...")
let iosImageName = "AppIcon_\(Int(iosIconSize))x\(Int(iosIconSize)).png"
let iosUrl = URL(fileURLWithPath: appIconsDir).appendingPathComponent(iosImageName)
if renderIcon(size: iosIconSize, scale: 1.0, outputPath: iosUrl.path) {
    print("  ✅ \(iosImageName)")
}

print("\n🎨 Generating app logos (for UI use)...")
for size in appLogoSizes {
    let imageName = "ChipLogo_\(Int(size))x\(Int(size))@2x.png"
    let url = URL(fileURLWithPath: appLogosDir).appendingPathComponent(imageName)
    
    if renderIcon(size: size, scale: 2.0, outputPath: url.path) {
        print("  ✅ \(imageName)")
    }
}

print("\n✅ Logo generation complete!")

