import SwiftUI

/// The four balls used in standard American six-wicket croquet.
/// Play order is Blue, Red, Black, Yellow.
enum Ball: String, CaseIterable, Codable, Identifiable {
    case blue
    case red
    case black
    case yellow

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// The team this ball belongs to. Blue + Black play against Red + Yellow.
    var team: Team {
        switch self {
        case .blue, .black: return .blueBlack
        case .red, .yellow: return .redYellow
        }
    }

    /// Fill color used to represent the ball in the UI.
    var color: Color {
        switch self {
        case .blue: return Color(red: 0.10, green: 0.35, blue: 0.85)
        case .red: return Color(red: 0.85, green: 0.15, blue: 0.15)
        case .black: return Color(red: 0.12, green: 0.12, blue: 0.14)
        case .yellow: return Color(red: 0.98, green: 0.80, blue: 0.10)
        }
    }

    /// A legible foreground color for text/symbols drawn on top of `color`.
    var onColor: Color {
        switch self {
        case .yellow: return .black
        default: return .white
        }
    }
}
