import Foundation

/// Firmware and platform identity, from `systeminfo.get_system_info`.
public struct SystemInfo: Equatable, Identifiable {
    public var id: String { "\(model)-\(firmwareVersion)" }

    public var model: String
    public var boardName: String
    public var platform: String
    public var firmwareVersion: String
    public var dumaOSVersion: String
    public var uptime: TimeInterval
    public var loadAverage: [Double]
    public var routerDate: String

    public init(
        model: String = "—",
        boardName: String = "—",
        platform: String = "—",
        firmwareVersion: String = "—",
        dumaOSVersion: String = "—",
        uptime: TimeInterval = 0,
        loadAverage: [Double] = [],
        routerDate: String = ""
    ) {
        self.model = model
        self.boardName = boardName
        self.platform = platform
        self.firmwareVersion = firmwareVersion
        self.dumaOSVersion = dumaOSVersion
        self.uptime = uptime
        self.loadAverage = loadAverage
        self.routerDate = routerDate
    }

    /// Lenient parser. DumaOS builds differ slightly in which keys they emit,
    /// so every field falls back rather than failing the whole response.
    public init(json: JSONValue) {
        self.init()
        model = json["model"]?.stringValue ?? json["board_name"]?.stringValue ?? "—"
        boardName = json["board_name"]?.stringValue ?? "—"
        platform = json["platform"]?.stringValue ?? "—"
        firmwareVersion = json["firmware_version"]?.stringValue
            ?? json["version"]?.stringValue ?? "—"
        dumaOSVersion = json["dumaos_version"]?.stringValue
            ?? json["dumaos"]?["version"]?.stringValue ?? "—"
        uptime = json["uptime"]?.doubleValue ?? 0
        routerDate = json["date"]?.stringValue ?? ""

        if let load = json["load"]?.arrayValue {
            loadAverage = load.compactMap(\.doubleValue)
        } else if let load = json["load"]?.doubleValue {
            loadAverage = [load]
        }
    }
}

/// CPU utilisation, from `systeminfo.get_cpu_info`.
public struct CPUInfo: Equatable {
    /// Per-core utilisation in the range 0...1.
    public var coreUsage: [Double]

    public init(coreUsage: [Double] = []) {
        self.coreUsage = coreUsage
    }

    public var averageUsage: Double {
        guard !coreUsage.isEmpty else { return 0 }
        return coreUsage.reduce(0, +) / Double(coreUsage.count)
    }

    public init(json: JSONValue) {
        // Seen shapes: [0.12, 0.30], [{usage: 12}], {usage: 12}, {cpus: [...]}.
        var values: [Double] = []
        if let array = json.arrayValue {
            values = array.compactMap { entry in
                entry.doubleValue ?? entry["usage"]?.doubleValue ?? entry["used"]?.doubleValue
            }
        } else if let cpus = json["cpus"]?.arrayValue {
            values = cpus.compactMap { $0.doubleValue ?? $0["usage"]?.doubleValue }
        } else if let usage = json["usage"]?.doubleValue ?? json["used"]?.doubleValue {
            values = [usage]
        }
        // Normalise percentages to a 0...1 fraction.
        self.init(coreUsage: values.map { $0 > 1 ? $0 / 100 : $0 })
    }
}

/// Memory or flash utilisation, from `systeminfo.get_ram_info` / `get_flash_info`.
public struct StorageInfo: Equatable {
    public var totalBytes: Double
    public var usedBytes: Double

    public init(totalBytes: Double = 0, usedBytes: Double = 0) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
    }

    public var freeBytes: Double { max(0, totalBytes - usedBytes) }

    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, usedBytes / totalBytes))
    }

    /// DumaOS reports these in kilobytes on some builds and bytes on others;
    /// `scale` lets the caller normalise.
    public init(json: JSONValue, scale: Double = 1) {
        let total = json["total"]?.doubleValue ?? json["size"]?.doubleValue ?? 0
        let free = json["free"]?.doubleValue ?? json["available"]?.doubleValue
        let used = json["used"]?.doubleValue ?? (free.map { total - $0 }) ?? 0
        self.init(totalBytes: total * scale, usedBytes: max(0, used) * scale)
    }
}

/// WAN interface counters, from `systeminfo.get_network_statistics`.
public struct NetworkStatistics: Equatable {
    public var wanIPAddress: String
    public var receivedBytes: Double
    public var transmittedBytes: Double
    public var receivedPackets: Double
    public var transmittedPackets: Double
    public var receivedDropped: Double
    public var transmittedDropped: Double

    public init(
        wanIPAddress: String = "—",
        receivedBytes: Double = 0,
        transmittedBytes: Double = 0,
        receivedPackets: Double = 0,
        transmittedPackets: Double = 0,
        receivedDropped: Double = 0,
        transmittedDropped: Double = 0
    ) {
        self.wanIPAddress = wanIPAddress
        self.receivedBytes = receivedBytes
        self.transmittedBytes = transmittedBytes
        self.receivedPackets = receivedPackets
        self.transmittedPackets = transmittedPackets
        self.receivedDropped = receivedDropped
        self.transmittedDropped = transmittedDropped
    }

    public init(json: JSONValue) {
        let received = json["received"]
        let transmitted = json["transmitted"]
        self.init(
            wanIPAddress: json["ip_address"]?.stringValue ?? "—",
            receivedBytes: received?["bytes"]?.doubleValue ?? 0,
            transmittedBytes: transmitted?["bytes"]?.doubleValue ?? 0,
            receivedPackets: received?["packets"]?.doubleValue ?? 0,
            transmittedPackets: transmitted?["packets"]?.doubleValue ?? 0,
            receivedDropped: received?["dropped"]?.doubleValue ?? 0,
            transmittedDropped: transmitted?["dropped"]?.doubleValue ?? 0
        )
    }
}

/// A point-in-time WAN throughput sample, derived by differencing successive
/// `NetworkStatistics` reads.
public struct ThroughputSample: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    /// Bits per second.
    public let downstream: Double
    public let upstream: Double

    public init(timestamp: Date, downstream: Double, upstream: Double) {
        self.timestamp = timestamp
        self.downstream = downstream
        self.upstream = upstream
    }

    /// Differences two counter reads into a rate. Returns `nil` when the
    /// counters wrapped or no time passed.
    public static func between(
        previous: NetworkStatistics,
        previousDate: Date,
        current: NetworkStatistics,
        currentDate: Date
    ) -> ThroughputSample? {
        let elapsed = currentDate.timeIntervalSince(previousDate)
        guard elapsed > 0.1 else { return nil }
        let down = current.receivedBytes - previous.receivedBytes
        let up = current.transmittedBytes - previous.transmittedBytes
        guard down >= 0, up >= 0 else { return nil }
        return ThroughputSample(
            timestamp: currentDate,
            downstream: down * 8 / elapsed,
            upstream: up * 8 / elapsed
        )
    }
}
