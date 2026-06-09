import Foundation

/// Whether the game is played with the standard four balls or the extended
/// six-ball set (adds Green and Orange).
enum GameFormat: String, Codable, CaseIterable, Identifiable {
    case fourBall
    case sixBall

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fourBall: return "4-ball"
        case .sixBall: return "6-ball"
        }
    }

    /// The balls in play for this format, in standard rotation order.
    var balls: [Ball] {
        switch self {
        case .fourBall: return [.blue, .red, .black, .yellow]
        case .sixBall: return [.blue, .red, .black, .yellow, .green, .orange]
        }
    }
}
