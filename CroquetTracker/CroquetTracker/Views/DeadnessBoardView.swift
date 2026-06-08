import SwiftUI

/// The classic deadness board. Each row is a striker ball; each column is a
/// ball it might be dead on. A filled cell means the row ball is dead on the
/// column ball. Tap any cell to toggle it.
struct DeadnessBoardView: View {
    @EnvironmentObject private var store: GameStore

    private let balls = Ball.allCases
    private let headerWidth: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deadness Board")
                .font(.headline)
            Text("Row is dead on column. Tap a cell to toggle.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                headerRow
                ForEach(balls) { striker in
                    row(for: striker)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: headerWidth, height: 1)
            ForEach(balls) { ball in
                BallChip(ball: ball, size: 26)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func row(for striker: Ball) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                BallChip(ball: striker, size: 26)
                Text(striker.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: headerWidth, alignment: .leading)

            ForEach(balls) { target in
                cell(striker: striker, target: target)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func cell(striker: Ball, target: Ball) -> some View {
        if striker == target {
            // A ball can't be dead on itself.
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemFill))
                .overlay(Image(systemName: "minus").font(.caption2).foregroundStyle(.tertiary))
                .frame(height: 40)
        } else {
            let dead = store.isDead(striker, on: target)
            Button {
                store.toggleDead(striker, on: target)
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(dead ? target.color : Color(.secondarySystemFill))
                    .frame(height: 40)
                    .overlay {
                        if dead {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(target.onColor)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(striker.displayName) dead on \(target.displayName)")
            .accessibilityValue(dead ? "dead" : "alive")
        }
    }
}
