import Foundation

/// The two sides in a standard four-ball game.
enum Team: String, Codable, CaseIterable, Identifiable {
    case blueBlack
    case redYellow

    var id: String { rawValue }

    /// Default human-readable name. Players can override this per game.
    var defaultName: String {
        switch self {
        case .blueBlack: return "Blue / Black"
        case .redYellow: return "Red / Yellow"
        }
    }

    var balls: [Ball] {
        switch self {
        case .blueBlack: return [.blue, .black]
        case .redYellow: return [.red, .yellow]
        }
    }
}
