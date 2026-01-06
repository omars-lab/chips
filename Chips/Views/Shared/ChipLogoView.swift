import SwiftUI

/// App logo featuring a CPU chip with button-like pressable effect
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
        ZStack {
            // Button base with shadow/3D effect
            RoundedRectangle(cornerRadius: cornerRadius)
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
                    RoundedRectangle(cornerRadius: cornerRadius)
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
                .scaleEffect(isPressed ? 0.95 : 1.0)
            
            // CPU Chip
            chipView
                .padding(padding)
        }
        .frame(width: size, height: size)
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .appIcon: return size * 0.22
        case .inline: return size * 0.18
        case .detailed: return size * 0.15
        }
    }
    
    private var padding: CGFloat {
        size * 0.15
    }
    
    @ViewBuilder
    private var chipView: some View {
        ZStack {
            // Chip base
            RoundedRectangle(cornerRadius: chipCornerRadius)
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
                    RoundedRectangle(cornerRadius: chipCornerRadius)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            
            // Chip details
            chipDetails
        }
    }
    
    private var chipCornerRadius: CGFloat {
        size * 0.08
    }
    
    @ViewBuilder
    private var chipDetails: some View {
        VStack(spacing: spacing) {
            // Top row of pins
            HStack(spacing: pinSpacing) {
                ForEach(0..<pinCount, id: \.self) { _ in
                    pinView
                }
            }
            
            // Center area with circuit pattern
            ZStack {
                // Horizontal lines
                HStack(spacing: 0) {
                    ForEach(0..<circuitLines, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: circuitLineWidth, height: circuitLineThickness)
                        Spacer()
                    }
                }
                
                // Vertical lines
                VStack(spacing: 0) {
                    ForEach(0..<circuitLines, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: circuitLineThickness, height: circuitLineWidth)
                        Spacer()
                    }
                }
                
                // Center dot (CPU core)
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: centerDotSize, height: centerDotSize)
            }
            .frame(width: centerSize, height: centerSize)
            
            // Bottom row of pins
            HStack(spacing: pinSpacing) {
                ForEach(0..<pinCount, id: \.self) { _ in
                    pinView
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
    
    private var pinCount: Int {
        switch style {
        case .appIcon: return 4
        case .inline: return 5
        case .detailed: return 6
        }
    }
    
    private var spacing: CGFloat {
        size * 0.02
    }
    
    private var pinSpacing: CGFloat {
        size * 0.015
    }
    
    private var pinSize: CGFloat {
        size * 0.03
    }
    
    private var centerSize: CGFloat {
        size * 0.35
    }
    
    private var centerDotSize: CGFloat {
        size * 0.08
    }
    
    private var circuitLines: Int {
        switch style {
        case .appIcon: return 2
        case .inline: return 3
        case .detailed: return 4
        }
    }
    
    private var circuitLineWidth: CGFloat {
        size * 0.12
    }
    
    private var circuitLineThickness: CGFloat {
        size * 0.008
    }
    
    private var horizontalPadding: CGFloat {
        size * 0.05
    }
    
    private var pinView: some View {
        RoundedRectangle(cornerRadius: pinSize * 0.3)
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
            .frame(width: pinSize, height: pinSize * 1.5)
            .overlay(
                RoundedRectangle(cornerRadius: pinSize * 0.3)
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
            )
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

