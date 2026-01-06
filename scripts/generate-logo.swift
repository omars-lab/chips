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
            // Button base with shadow/3D effect
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: isPressed ? 0.85 : 0.95),
                            Color(white: isPressed ? 0.75 : 0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isPressed ? 0.3 : 0.6),
                                    Color.black.opacity(isPressed ? 0.1 : 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isPressed ? 1 : 2
                        )
                )
                .shadow(
                    color: Color.black.opacity(isPressed ? 0.1 : 0.3),
                    radius: isPressed ? 2 : 8,
                    x: 0,
                    y: isPressed ? 1 : 4
                )
            
            // CPU Chip
            chipView
                .padding(size * 0.15)
        }
        .frame(width: size, height: size)
    }
    
    private var chipView: some View {
        ZStack {
            // Chip base
            RoundedRectangle(cornerRadius: size * 0.08)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.9),
                            Color.blue.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            
            // Chip details
            VStack(spacing: size * 0.02) {
                // Top row of pins
                HStack(spacing: size * 0.015) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: size * 0.009)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.3)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: size * 0.03, height: size * 0.045)
                            .overlay(
                                RoundedRectangle(cornerRadius: size * 0.009)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                            )
                    }
                }
                
                // Center area with circuit pattern
                ZStack {
                    // Horizontal lines
                    HStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: size * 0.12, height: size * 0.008)
                            Spacer()
                        }
                    }
                    
                    // Vertical lines
                    VStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: size * 0.008, height: size * 0.12)
                            Spacer()
                        }
                    }
                    
                    // Center dot (CPU core)
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: size * 0.08, height: size * 0.08)
                }
                .frame(width: size * 0.35, height: size * 0.35)
                
                // Bottom row of pins
                HStack(spacing: size * 0.015) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: size * 0.009)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.3)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: size * 0.03, height: size * 0.045)
                            .overlay(
                                RoundedRectangle(cornerRadius: size * 0.009)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                            )
                    }
                }
            }
            .padding(.horizontal, size * 0.05)
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

