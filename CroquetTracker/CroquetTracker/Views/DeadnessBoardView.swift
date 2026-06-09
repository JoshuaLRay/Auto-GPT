import SwiftUI

/// The classic deadness board. Each row is a striker ball; each column is a
/// ball it might be dead on. A filled cell means the row ball is dead on the
/// column ball. Tap any cell to toggle it.
struct DeadnessBoardView: View {
    @EnvironmentObject private var store: GameStore

    private var balls: [Ball] { store.game.balls }
    private let headerWidth: CGFloat = 60

    // Tighten the grid when there are more columns (six-ball).
    private var chipSize: CGFloat { balls.count > 4 ? 22 : 26 }
    private var cellHeight: CGFloat { balls.count > 4 ? 36 : 40 }
    private var cellSpacing: CGFloat { balls.count > 4 ? 4 : 6 }

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
        HStack(spacing: cellSpacing) {
            Color.clear.frame(width: headerWidth, height: 1)
            ForEach(balls) { ball in
                BallChip(ball: ball, size: chipSize)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func row(for striker: Ball) -> some View {
        HStack(spacing: cellSpacing) {
            HStack(spacing: 6) {
                BallChip(ball: striker, size: chipSize)
                Text(striker.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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
                .frame(height: cellHeight)
        } else {
            let dead = store.isDead(striker, on: target)
            Button {
                store.toggleDead(striker, on: target)
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(dead ? target.color : Color(.secondarySystemFill))
                    .frame(height: cellHeight)
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
