import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// App logo using PNG images from logo-assets/app-logos
struct ChipLogoView: View {
    let size: CGFloat
    let isPressed: Bool
    let style: LogoStyle
    
    enum LogoStyle {
        case appIcon    // For app icon - simpler, more recognizable
        case inline     // For inline use in UI - more detailed
        case detailed   // Most detailed version
    }
    
    init(size: CGFloat = 100, isPressed: Bool = false, style: LogoStyle = .appIcon) {
        self.size = size
        self.isPressed = isPressed
        self.style = style
    }
    
    var body: some View {
        logoImageView
            .frame(width: size, height: size)
            .scaleEffect(isPressed ? 0.95 : 1.0)
    }
    
    @ViewBuilder
    private var logoImageView: some View {
        if let image = loadLogoImage() {
            platformImage(image)
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback placeholder
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Text("Logo")
                        .font(.system(size: size * 0.2))
                        .foregroundColor(.gray)
                )
        }
    }
    
    @ViewBuilder
    private func platformImage(_ image: PlatformImage) -> Image {
        #if os(macOS)
        Image(nsImage: image)
        #else
        Image(uiImage: image)
        #endif
    }
    
    /// Loads the appropriate logo image from bundle resources
    private func loadLogoImage() -> PlatformImage? {
        guard let imageName = imageNameForSize(size) else { return nil }
        
        // When added as resources, files are at the root of the bundle
        // Try multiple approaches to find the image
        #if os(macOS)
        // Try 1: Direct path lookup (files are in bundle root when added as resources)
        if let imagePath = Bundle.main.path(forResource: imageName, ofType: "png"),
           let image = NSImage(contentsOfFile: imagePath) {
            return image
        }
        // Try 2: As asset name (if added to Assets.xcassets)
        if let image = NSImage(named: imageName) {
            return image
        }
        // Try 3: With directory path (if structure is preserved)
        if let resourcePath = Bundle.main.resourcePath {
            let fullPath = "\(resourcePath)/logo-assets/app-logos/\(imageName).png"
            if let image = NSImage(contentsOfFile: fullPath) {
                return image
            }
        }
        #else
        // Try 1: Direct path lookup (files are in bundle root when added as resources)
        if let imagePath = Bundle.main.path(forResource: imageName, ofType: "png"),
           let image = UIImage(contentsOfFile: imagePath) {
            return image
        }
        // Try 2: As asset name (if added to Assets.xcassets)
        if let image = UIImage(named: imageName) {
            return image
        }
        // Try 3: With directory path (if structure is preserved)
        if let resourcePath = Bundle.main.resourcePath {
            let fullPath = "\(resourcePath)/logo-assets/app-logos/\(imageName).png"
            if let image = UIImage(contentsOfFile: fullPath) {
                return image
            }
        }
        #endif
        
        return nil
    }
    
    /// Selects the appropriate image name based on the requested size
    /// Images are @2x versions, so we need to match based on the @2x pixel size
    private func imageNameForSize(_ size: CGFloat) -> String? {
        // Images are @2x, so actual pixel sizes are:
        // ChipLogo_40x40@2x.png = 80x80 pixels
        // ChipLogo_60x60@2x.png = 120x120 pixels
        // ChipLogo_80x80@2x.png = 160x160 pixels
        // ChipLogo_120x120@2x.png = 240x240 pixels
        // ChipLogo_180x180@2x.png = 360x360 pixels
        // ChipLogo_240x240@2x.png = 480x480 pixels
        
        // Use a simpler approach: select based on requested size
        switch size {
        case 0..<50:
            return "ChipLogo_40x40@2x"
        case 50..<70:
            return "ChipLogo_60x60@2x"
        case 70..<100:
            return "ChipLogo_80x80@2x"
        case 100..<150:
            return "ChipLogo_120x120@2x"
        case 150..<210:
            return "ChipLogo_180x180@2x"
        default:
            return "ChipLogo_240x240@2x"
        }
    }
}

// MARK: - Animated Pressable Version

struct PressableChipLogoView: View {
    @State private var isPressed = false
    let size: CGFloat
    let style: ChipLogoView.LogoStyle
    let onPress: (() -> Void)?
    
    init(size: CGFloat = 100, style: ChipLogoView.LogoStyle = .appIcon, onPress: (() -> Void)? = nil) {
        self.size = size
        self.style = style
        self.onPress = onPress
    }
    
    var body: some View {
        ChipLogoView(size: size, isPressed: isPressed, style: style)
            .onTapGesture {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                    onPress?()
                }
            }
    }
}

// MARK: - Preview

#Preview("App Icon Style") {
    VStack(spacing: 40) {
        ChipLogoView(size: 120, style: .appIcon)
        ChipLogoView(size: 120, isPressed: true, style: .appIcon)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Inline Style") {
    VStack(spacing: 40) {
        ChipLogoView(size: 100, style: .inline)
        PressableChipLogoView(size: 100, style: .inline) {
            print("Logo pressed!")
        }
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Detailed Style") {
    ChipLogoView(size: 150, style: .detailed)
        .padding()
        .background(Color.gray.opacity(0.2))
}

