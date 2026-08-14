import Foundation

/// The WAN speeds Congestion Control shapes against, from `qos.get_bandwidth`.
public struct BandwidthSettings: Equatable {
    /// Downstream limit in megabits per second.
    public var downloadMbps: Double
    /// Upstream limit in megabits per second.
    public var uploadMbps: Double

    public init(downloadMbps: Double = 0, uploadMbps: Double = 0) {
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
    }

    /// DumaOS stores bandwidth in kilobits per second.
    public init(downKbps: Double, upKbps: Double) {
        self.init(downloadMbps: downKbps / 1000, uploadMbps: upKbps / 1000)
    }

    public var downKbps: Double { downloadMbps * 1000 }
    public var upKbps: Double { uploadMbps * 1000 }
}

/// How aggressively Anti-Bufferbloat throttles the link, from `qos.get_link_throttle`.
public struct ThrottleSettings: Equatable {
    public var isEnabled: Bool
    /// Fraction of the configured downstream bandwidth to allow, 0...1.
    public var downstreamFraction: Double
    /// Fraction of the configured upstream bandwidth to allow, 0...1.
    public var upstreamFraction: Double

    public init(
        isEnabled: Bool = false,
        downstreamFraction: Double = 0.7,
        upstreamFraction: Double = 0.7
    ) {
        self.isEnabled = isEnabled
        self.downstreamFraction = downstreamFraction
        self.upstreamFraction = upstreamFraction
    }

    public init(json: JSONValue) {
        // The R-App sends `{ dthrottle = 0.7, uthrottle = 0.7, enabled = true }`.
        self.init(
            isEnabled: json["enabled"]?.boolValue ?? json["do_throttle"]?.boolValue ?? false,
            downstreamFraction: Self.normalize(json["dthrottle"]?.doubleValue ?? json["down"]?.doubleValue),
            upstreamFraction: Self.normalize(json["uthrottle"]?.doubleValue ?? json["up"]?.doubleValue)
        )
    }

    private static func normalize(_ value: Double?) -> Double {
        guard let value else { return 0.7 }
        return value > 1 ? min(1, value / 100) : max(0, value)
    }
}

/// One device's share of the bandwidth pie, from `qos.get_bandwidth_dist_tree`.
public struct BandwidthAllocation: Identifiable, Equatable {
    public var id: String
    public var name: String
    /// Share of downstream bandwidth, 0...1.
    public var downstreamShare: Double
    /// Share of upstream bandwidth, 0...1.
    public var upstreamShare: Double
    /// When true, unused bandwidth from this node is lent to other devices.
    public var sharesExcess: Bool

    public init(
        id: String,
        name: String,
        downstreamShare: Double,
        upstreamShare: Double,
        sharesExcess: Bool = true
    ) {
        self.id = id
        self.name = name
        self.downstreamShare = downstreamShare
        self.upstreamShare = upstreamShare
        self.sharesExcess = sharesExcess
    }

    /// Parses a node of the distribution tree. The tree is nested (`children`),
    /// but the app only presents the leaf devices.
    public static func flatten(_ json: JSONValue, deviceNames: [String: String] = [:]) -> [BandwidthAllocation] {
        var output: [BandwidthAllocation] = []

        func visit(_ node: JSONValue) {
            let children = node["children"]?.arrayValue ?? []
            if children.isEmpty {
                let identifier = node["devid"]?.stringValue
                    ?? node["device"]?.stringValue
                    ?? node["node"]?.stringValue
                    ?? node["name"]?.stringValue
                guard let identifier, !identifier.isEmpty else { return }
                let share = node["normprop"]?.doubleValue ?? node["prop"]?.doubleValue ?? 0
                output.append(
                    BandwidthAllocation(
                        id: identifier,
                        name: deviceNames[identifier] ?? node["name"]?.stringValue ?? identifier,
                        downstreamShare: node["down_normprop"]?.doubleValue ?? share,
                        upstreamShare: node["up_normprop"]?.doubleValue ?? share,
                        sharesExcess: node["share_excess"]?.boolValue ?? true
                    )
                )
            } else {
                children.forEach(visit)
            }
        }

        if let roots = json.arrayValue {
            roots.forEach(visit)
        } else {
            visit(json)
        }
        return output
    }
}

/// A Traffic Prioritisation entry, from `qos.get_hyperlane_services`.
public struct HyperlaneService: Identifiable, Equatable {
    public var id: String
    public var name: String
    public var isEnabled: Bool
    public var deviceID: String?

    public init(id: String, name: String, isEnabled: Bool, deviceID: String? = nil) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.deviceID = deviceID
    }

    public init?(json: JSONValue) {
        let identifier = json["id"]?.stringValue ?? json["name"]?.stringValue
        guard let identifier, !identifier.isEmpty else { return nil }
        self.init(
            id: identifier,
            name: json["name"]?.stringValue ?? identifier,
            isEnabled: json["enabled"]?.boolValue ?? true,
            deviceID: json["device"]?.stringValue ?? json["devid"]?.stringValue
        )
    }
}

/// Everything the Congestion Control screen needs in one value.
public struct QoSSnapshot: Equatable {
    public var bandwidth: BandwidthSettings
    public var throttle: ThrottleSettings
    public var allocations: [BandwidthAllocation]
    public var services: [HyperlaneService]
    public var hardwareAccelerationEnabled: Bool

    public init(
        bandwidth: BandwidthSettings = BandwidthSettings(),
        throttle: ThrottleSettings = ThrottleSettings(),
        allocations: [BandwidthAllocation] = [],
        services: [HyperlaneService] = [],
        hardwareAccelerationEnabled: Bool = false
    ) {
        self.bandwidth = bandwidth
        self.throttle = throttle
        self.allocations = allocations
        self.services = services
        self.hardwareAccelerationEnabled = hardwareAccelerationEnabled
    }
}
