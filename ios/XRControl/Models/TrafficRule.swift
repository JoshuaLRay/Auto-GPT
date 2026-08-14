import Foundation

/// A Traffic Controller rule, from `trafficcontroller.get_rules`.
public struct TrafficRule: Identifiable, Equatable {
    public enum Action: String, CaseIterable, Identifiable, Equatable {
        case allow
        case block
        case reject

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .allow: return "Allow"
            case .block: return "Block"
            case .reject: return "Reject"
            }
        }

        public var symbolName: String {
            switch self {
            case .allow: return "checkmark.circle.fill"
            case .block: return "hand.raised.fill"
            case .reject: return "xmark.octagon.fill"
            }
        }
    }

    public var id: String
    public var name: String
    public var isEnabled: Bool
    public var action: Action
    public var deviceID: String?
    public var services: [String]
    public var categories: [String]
    public var notificationsEnabled: Bool
    /// Index within the ordered rule list; lower runs first.
    public var order: Int

    public init(
        id: String,
        name: String,
        isEnabled: Bool = true,
        action: Action = .block,
        deviceID: String? = nil,
        services: [String] = [],
        categories: [String] = [],
        notificationsEnabled: Bool = false,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.action = action
        self.deviceID = deviceID
        self.services = services
        self.categories = categories
        self.notificationsEnabled = notificationsEnabled
        self.order = order
    }

    public init?(json: JSONValue, order: Int) {
        let identifier = json["id"]?.stringValue ?? json["index"]?.stringValue
        guard let identifier, !identifier.isEmpty else { return nil }

        // The rule stores its verdict as three mutually exclusive booleans.
        let action: Action
        if json["block"]?.boolValue == true {
            action = .block
        } else if json["reject"]?.boolValue == true {
            action = .reject
        } else if json["allow"]?.boolValue == true {
            action = .allow
        } else {
            action = Action(rawValue: json["action"]?.stringValue ?? "block") ?? .block
        }

        self.init(
            id: identifier,
            name: json["name"]?.stringValue ?? "Rule \(order + 1)",
            isEnabled: json["enabled"]?.boolValue ?? !(json["disabled"]?.boolValue ?? false),
            action: action,
            deviceID: json["device"]?.stringValue ?? json["deviceid"]?.stringValue,
            services: json["services"]?.arrayValue?.compactMap(\.stringValue) ?? [],
            categories: json["categories"]?.arrayValue?.compactMap(\.stringValue) ?? [],
            notificationsEnabled: json["notifications"]?.boolValue ?? false,
            order: order
        )
    }

    /// The subject line shown under the rule name.
    public var summary: String {
        var parts: [String] = []
        if !services.isEmpty { parts.append(services.joined(separator: ", ")) }
        if !categories.isEmpty { parts.append(categories.joined(separator: ", ")) }
        if parts.isEmpty { parts.append("All traffic") }
        return parts.joined(separator: " · ")
    }
}
