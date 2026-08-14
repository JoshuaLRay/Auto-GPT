import Foundation

public enum Format {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter
    }()

    public static func bytes(_ value: Double) -> String {
        byteFormatter.string(fromByteCount: Int64(max(0, value)))
    }

    /// Formats a bit-rate with the unit the magnitude calls for.
    public static func bitsPerSecond(_ value: Double) -> String {
        let magnitude = max(0, value)
        switch magnitude {
        case 0..<1_000:
            return "\(Int(magnitude)) bps"
        case 1_000..<1_000_000:
            return String(format: "%.0f Kbps", magnitude / 1_000)
        case 1_000_000..<1_000_000_000:
            return String(format: "%.1f Mbps", magnitude / 1_000_000)
        default:
            return String(format: "%.2f Gbps", magnitude / 1_000_000_000)
        }
    }

    public static func megabits(_ value: Double) -> String {
        value < 10
            ? String(format: "%.1f Mbps", value)
            : String(format: "%.0f Mbps", value)
    }

    public static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// "4 days, 6 hours" — the router's uptime as the web UI shows it.
    public static func uptime(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 86_400 ? [.day, .hour] : [.hour, .minute]
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? "—"
    }

    public static func distance(kilometers: Double) -> String {
        kilometers < 10
            ? String(format: "%.1f km", kilometers)
            : "\(Int(kilometers.rounded())) km"
    }

    public static func milliseconds(_ value: Double) -> String {
        "\(Int(value.rounded())) ms"
    }
}
