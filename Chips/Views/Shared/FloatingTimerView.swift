import SwiftUI

/// Floating timer pill that shows active timer status
struct FloatingTimerView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var isExpanded = false

    var body: some View {
        if let timer = timerManager.activeTimer {
            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 0) {
                    Spacer()

                    if isExpanded {
                        expandedView(timer: timer)
                    } else {
                        compactView(timer: timer)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100) // Above tab bar
            }
            .animation(.spring(response: 0.3), value: isExpanded)
        }
    }

    // MARK: - Compact View

    private func compactView(timer: ManagedTimer) -> some View {
        Button {
            withAnimation {
                isExpanded = true
            }
        } label: {
            HStack(spacing: 8) {
                // Pulsing indicator
                Circle()
                    .fill(timer.isRunning ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .modifier(PulsingModifier(isAnimating: timer.isRunning))

                // Time
                Text(timer.formattedElapsed)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)

                // Progress ring (if expected duration)
                if timer.expectedDuration != nil {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: timer.progress)
                            .stroke(
                                timer.isOvertime ? Color.red : Color.green,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded View

    private func expandedView(timer: ManagedTimer) -> some View {
        VStack(spacing: 12) {
            // Header with close button
            HStack {
                Text(timer.chipTitle)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button {
                    withAnimation {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Timer display
            HStack(spacing: 16) {
                // Elapsed time
                VStack(spacing: 2) {
                    Text(timer.formattedElapsed)
                        .font(.system(size: 32, weight: .medium, design: .monospaced))
                        .foregroundStyle(timer.isOvertime ? .red : .primary)

                    if let remaining = timer.formattedRemaining {
                        Text(timer.isOvertime ? "overtime" : "remaining: \(remaining)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Progress ring
                if timer.expectedDuration != nil {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 4)

                        Circle()
                            .trim(from: 0, to: min(timer.progress, 1.0))
                            .stroke(
                                timer.isOvertime ? Color.red : Color.green,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        if timer.isOvertime {
                            Image(systemName: "exclamationmark")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(width: 50, height: 50)
                }
            }

            // Controls
            HStack(spacing: 20) {
                // Play/Pause
                Button {
                    if timer.isRunning {
                        timerManager.pauseTimer()
                    } else {
                        timerManager.resumeTimer()
                    }
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }

                // Stop
                Button {
                    _ = timerManager.stopTimer()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}

// MARK: - Pulsing Modifier

struct PulsingModifier: ViewModifier {
    let isAnimating: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .onAppear {
                guard isAnimating else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    withAnimation {
                        isPulsing = false
                    }
                }
            }
    }
}

// MARK: - Timer Overlay Modifier

struct TimerOverlayModifier: ViewModifier {
    @ObservedObject var timerManager: TimerManager

    func body(content: Content) -> some View {
        content
            .overlay {
                FloatingTimerView(timerManager: timerManager)
            }
    }
}

extension View {
    func timerOverlay(_ timerManager: TimerManager) -> some View {
        modifier(TimerOverlayModifier(timerManager: timerManager))
    }
}

// MARK: - Preview

#Preview {
    struct PreviewContainer: View {
        @StateObject private var timerManager = TimerManager.shared

        var body: some View {
            ZStack {
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()

                VStack {
                    Button("Start Timer") {
                        timerManager.startTimer(
                            chipID: UUID(),
                            chipTitle: "30 Min HIIT Workout",
                            expectedDuration: 1800
                        )
                    }
                    .padding()
                }

                FloatingTimerView(timerManager: timerManager)
            }
        }
    }

    return PreviewContainer()
}
