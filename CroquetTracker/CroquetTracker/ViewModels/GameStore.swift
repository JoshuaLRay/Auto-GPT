import Foundation
import Combine

/// Owns the live game and persists it to `UserDefaults` after every change so
/// the in-progress match survives app restarts.
@MainActor
final class GameStore: ObservableObject {
    @Published var game: GameState {
        didSet { save() }
    }

    private let storageKey = "croquet.game.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(GameState.self, from: data) {
            game = decoded
        } else {
            game = .newGame()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(game) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - Mutations

    /// Start over with a clean board, keeping nothing from the previous game
    /// except the chosen format.
    func resetGame() {
        game = .newGame(format: game.format)
    }

    /// Switch between four- and six-ball play without disturbing balls that
    /// exist in both: their wicket and deadness carry over. Six-ball adds Green
    /// and Orange fresh; four-ball drops them (and any deadness pointing at them).
    func setFormat(_ format: GameFormat) {
        guard format != game.format else { return }
        let newBalls = format.balls
        let updatedStates: [BallState] = newBalls.map { ball in
            if var existing = game.ballStates.first(where: { $0.ball == ball }) {
                existing.deadOn = existing.deadOn.filter { newBalls.contains($0) }
                return existing
            }
            return BallState(ball: ball)
        }
        game.format = format
        game.ballStates = updatedStates
    }

    private func index(of ball: Ball) -> Int? {
        game.ballStates.firstIndex { $0.ball == ball }
    }

    // MARK: Deadness

    func isDead(_ striker: Ball, on target: Ball) -> Bool {
        guard striker != target, let i = index(of: striker) else { return false }
        return game.ballStates[i].deadOn.contains(target)
    }

    /// Manually flip whether `striker` is dead on `target`.
    func toggleDead(_ striker: Ball, on target: Ball) {
        guard striker != target, let i = index(of: striker) else { return }
        if game.ballStates[i].deadOn.contains(target) {
            game.ballStates[i].deadOn.remove(target)
        } else {
            game.ballStates[i].deadOn.insert(target)
        }
    }

    /// Wipe a ball's deadness — e.g. after it scores its wicket.
    func clearDeadness(for ball: Ball) {
        guard let i = index(of: ball) else { return }
        game.ballStates[i].deadOn.removeAll()
    }

    // MARK: Wickets

    /// Record that a ball scored its next wicket: advance it and clear its
    /// deadness, matching American rules.
    func scoreWicket(for ball: Ball) {
        guard let i = index(of: ball) else { return }
        guard !game.ballStates[i].isFinished else { return }
        game.ballStates[i].nextWicketIndex = min(
            game.ballStates[i].nextWicketIndex + 1, Wicket.finishedIndex
        )
        game.ballStates[i].deadOn.removeAll()
    }

    /// Step the target wicket back without touching deadness (for corrections).
    func retreatWicket(for ball: Ball) {
        guard let i = index(of: ball) else { return }
        game.ballStates[i].nextWicketIndex = max(game.ballStates[i].nextWicketIndex - 1, 0)
    }

    // MARK: Names

    func setPlayerName(_ name: String, for ball: Ball) {
        guard let i = index(of: ball) else { return }
        game.ballStates[i].playerName = name
    }

    func setTeamName(_ name: String, for team: Team) {
        game.teamNames[team] = name
    }
}
