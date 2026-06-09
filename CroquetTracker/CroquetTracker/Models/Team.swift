import Foundation

/// The two sides in a standard four-ball game.
enum Team: String, Codable, CaseIterable, Identifiable {
    case blueBlack
    case redYellow

    var id: String { rawValue }
}
