import SwiftUI

/// A small colored circle representing a ball, optionally showing a label.
struct BallChip: View {
    let ball: Ball
    var size: CGFloat = 28
    var label: String? = nil

    var body: some View {
        Circle()
            .fill(ball.color)
            .frame(width: size, height: size)
            .overlay {
                if let label {
                    Text(label)
                        .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                        .foregroundStyle(ball.onColor)
                }
            }
            .overlay(
                Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            .accessibilityLabel(ball.displayName)
    }
}
