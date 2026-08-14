import SwiftUI

/// Colour and type tokens, kept in one place so every screen reads as one app.
public enum Theme {
    public static let accent = Color(red: 0.20, green: 0.78, blue: 0.55)
    public static let warning = Color(red: 0.98, green: 0.68, blue: 0.20)
    public static let danger = Color(red: 0.95, green: 0.35, blue: 0.35)
    public static let downstream = Color(red: 0.31, green: 0.62, blue: 0.98)
    public static let upstream = Color(red: 0.62, green: 0.42, blue: 0.94)

    public static let cardCornerRadius: CGFloat = 16
}

/// Rounded container used for every dashboard tile and settings block.
public struct Card<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

/// A labelled metric with an optional caption, used across the dashboard.
public struct StatTile: View {
    let title: String
    let value: String
    let caption: String?
    let systemImage: String
    let tint: Color

    public init(
        title: String,
        value: String,
        caption: String? = nil,
        systemImage: String,
        tint: Color = Theme.accent
    ) {
        self.title = title
        self.value = value
        self.caption = caption
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .labelStyle(.titleAndIcon)

                Text(value)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// Horizontal usage bar, e.g. RAM and flash.
public struct UsageBar: View {
    let fraction: Double
    let tint: Color

    public init(fraction: Double, tint: Color = Theme.accent) {
        self.fraction = fraction
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(tint)
                    .frame(width: max(2, proxy.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 8)
        .accessibilityValue(Text(fraction.formatted(.percent.precision(.fractionLength(0)))))
    }
}

/// Inline, dismissible error presentation. Used instead of alerts so a failing
/// background refresh never interrupts what the user is doing.
public struct ErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)?

    public init(message: String, onRetry: (() -> Void)? = nil) {
        self.message = message
        self.onRetry = onRetry
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)

            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onRetry {
                Button("Retry", action: onRetry)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.warning.opacity(0.12))
        )
    }
}

/// Empty-state placeholder for lists that have nothing to show yet.
public struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
