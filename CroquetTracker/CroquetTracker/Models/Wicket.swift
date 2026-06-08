import Foundation

/// The ordered course of a full six-wicket game: hoops 1–6, the six "back"
/// hoops, then the finishing stake. `index` runs 0...12, where 12 means the
/// ball has staked out and finished.
enum Wicket {
    /// Labels for each position a ball can be working toward, indexed 0...12.
    static let labels: [String] = [
        "1", "2", "3", "4", "5", "6",
        "1-back", "2-back", "3-back", "4-back",
        "Penult", "Rover", "Stake"
    ]

    /// The index of the final position (the stake). A ball at this index is done.
    static let finishedIndex = labels.count - 1

    /// Short label for a given progress index, clamped to the valid range.
    static func label(for index: Int) -> String {
        let clamped = min(max(index, 0), finishedIndex)
        return labels[clamped]
    }

    static func isFinished(_ index: Int) -> Bool {
        index >= finishedIndex
    }
}
