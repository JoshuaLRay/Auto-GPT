import SwiftUI

/// A card per ball showing its team, the player's name, the wicket it's
/// running for next, and a quick "scored" control.
struct BallTrackerView: View {
    @EnvironmentObject private var store: GameStore
    let ball: Ball

    private var state: BallState { store.game.state(for: ball) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            playerField
            wicketControls
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(ball.color.opacity(0.6), lineWidth: 2)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            BallChip(ball: ball, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(ball.displayName)
                    .font(.headline)
                Text(store.game.name(for: ball.team))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var playerField: some View {
        TextField("Player name", text: Binding(
            get: { state.playerName },
            set: { store.setPlayerName($0, for: ball) }
        ))
        .textFieldStyle(.roundedBorder)
    }

    private var wicketControls: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.isFinished ? "Finished" : "Next wicket")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(state.nextWicketLabel)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(state.isFinished ? .green : .primary)
            }
            Spacer()
            Button {
                store.retreatWicket(for: ball)
            } label: {
                Image(systemName: "minus.circle.fill").font(.title)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Step \(ball.displayName) back a wicket")

            Button {
                store.scoreWicket(for: ball)
            } label: {
                Label("Scored", systemImage: "checkmark.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(ball.team == .blueBlack ? .blue : .red)
            .disabled(state.isFinished)
            .accessibilityHint("Advances the wicket and clears deadness")
        }
    }
}
