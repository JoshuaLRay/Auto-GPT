import Foundation

/// All tracked state for a single ball: who's playing it, the wicket it's
/// running for next, and which balls it is currently dead on.
struct BallState: Codable, Identifiable {
    let ball: Ball
    var playerName: String
    /// Index into `Wicket.labels` for the next wicket this ball must score.
    var nextWicketIndex: Int
    /// Balls this ball has already roqueted this turn and may not hit again
    /// until it scores its next wicket.
    var deadOn: Set<Ball>

    var id: Ball { ball }

    init(ball: Ball, playerName: String = "", nextWicketIndex: Int = 0, deadOn: Set<Ball> = []) {
        self.ball = ball
        self.playerName = playerName
        self.nextWicketIndex = nextWicketIndex
        self.deadOn = deadOn
    }

    var isFinished: Bool { Wicket.isFinished(nextWicketIndex) }
    var nextWicketLabel: String { Wicket.label(for: nextWicketIndex) }
}

/// The full game: per-ball state plus editable team names.
struct GameState: Codable {
    var ballStates: [BallState]
    var teamNames: [Team: String]

    /// A fresh game with balls at wicket 1 and clean deadness.
    static func newGame() -> GameState {
        GameState(
            ballStates: Ball.allCases.map { BallState(ball: $0) },
            teamNames: [
                .blueBlack: Team.blueBlack.defaultName,
                .redYellow: Team.redYellow.defaultName
            ]
        )
    }

    func name(for team: Team) -> String {
        let custom = teamNames[team]?.trimmingCharacters(in: .whitespaces)
        if let custom, !custom.isEmpty { return custom }
        return team.defaultName
    }

    func state(for ball: Ball) -> BallState {
        ballStates.first { $0.ball == ball } ?? BallState(ball: ball)
    }
}

// MARK: - Codable support for the [Team: String] dictionary

extension GameState {
    enum CodingKeys: String, CodingKey {
        case ballStates
        case teamNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ballStates = try container.decode([BallState].self, forKey: .ballStates)
        // Stored as [String: String] so it round-trips cleanly through JSON.
        let rawNames = try container.decodeIfPresent([String: String].self, forKey: .teamNames) ?? [:]
        var decoded: [Team: String] = [:]
        for (key, value) in rawNames {
            if let team = Team(rawValue: key) { decoded[team] = value }
        }
        teamNames = decoded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ballStates, forKey: .ballStates)
        let rawNames = Dictionary(uniqueKeysWithValues: teamNames.map { ($0.key.rawValue, $0.value) })
        try container.encode(rawNames, forKey: .teamNames)
    }
}
