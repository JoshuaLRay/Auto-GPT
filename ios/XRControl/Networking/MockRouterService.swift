import Foundation

/// An in-memory router used by SwiftUI previews, unit tests, and the app's
/// "Explore in demo mode" entry point — so the interface can be evaluated
/// without an XR500 on the network.
public actor MockRouterService: RouterServicing {
    private var geo = GeoFilterSnapshot(
        settings: GeoFilterSettings(
            mode: .filtering,
            strictMode: false,
            radiusKilometers: 1_200,
            pingAssistMilliseconds: 35,
            homeLatitude: 40.7128,
            homeLongitude: -74.0060
        ),
        peers: [
            GeoPeer(id: "1", ipAddress: "104.16.248.249", latitude: 40.71, longitude: -74.01,
                    kind: .server, isAllowed: true, pingMilliseconds: 8, countryName: "United States"),
            GeoPeer(id: "2", ipAddress: "35.190.247.1", latitude: 41.88, longitude: -87.63,
                    kind: .server, pingMilliseconds: 26, countryName: "United States"),
            GeoPeer(id: "3", ipAddress: "52.94.236.248", latitude: 39.04, longitude: -77.49,
                    kind: .peer, pingMilliseconds: 19, countryName: "United States"),
            GeoPeer(id: "4", ipAddress: "34.117.59.81", latitude: 51.51, longitude: -0.13,
                    kind: .server, isDenied: true, pingMilliseconds: 92, countryName: "United Kingdom"),
            GeoPeer(id: "5", ipAddress: "13.107.42.14", latitude: 47.61, longitude: -122.33,
                    kind: .peer, pingMilliseconds: 71, countryName: "United States"),
            GeoPeer(id: "6", ipAddress: "18.196.0.1", latitude: 50.11, longitude: 8.68,
                    kind: .server, pingMilliseconds: 108, countryName: "Germany")
        ]
    )

    private var qos = QoSSnapshot(
        bandwidth: BandwidthSettings(downloadMbps: 450, uploadMbps: 42),
        throttle: ThrottleSettings(isEnabled: true, downstreamFraction: 0.7, upstreamFraction: 0.7),
        allocations: [
            BandwidthAllocation(id: "aa:bb:cc:dd:ee:01", name: "PlayStation 5", downstreamShare: 0.40, upstreamShare: 0.45),
            BandwidthAllocation(id: "aa:bb:cc:dd:ee:02", name: "Living room TV", downstreamShare: 0.25, upstreamShare: 0.15),
            BandwidthAllocation(id: "aa:bb:cc:dd:ee:03", name: "Work laptop", downstreamShare: 0.20, upstreamShare: 0.25),
            BandwidthAllocation(id: "aa:bb:cc:dd:ee:04", name: "iPhone", downstreamShare: 0.15, upstreamShare: 0.15)
        ],
        services: [
            HyperlaneService(id: "svc-1", name: "Call of Duty", isEnabled: true, deviceID: "aa:bb:cc:dd:ee:01"),
            HyperlaneService(id: "svc-2", name: "Video conferencing", isEnabled: false, deviceID: "aa:bb:cc:dd:ee:03")
        ],
        hardwareAccelerationEnabled: false
    )

    private var devices: [NetworkDevice] = [
        NetworkDevice(id: "aa:bb:cc:dd:ee:01", name: "PlayStation 5", ipAddress: "192.168.1.24",
                      macAddress: "aa:bb:cc:dd:ee:01", deviceType: "playstation", isOnline: true,
                      connectionType: "wired", linkSpeed: 1000),
        NetworkDevice(id: "aa:bb:cc:dd:ee:02", name: "Living room TV", ipAddress: "192.168.1.31",
                      macAddress: "aa:bb:cc:dd:ee:02", deviceType: "tv", isOnline: true,
                      connectionType: "wireless", ssid: "Nighthawk-5G", linkSpeed: 433, signalStrength: 78),
        NetworkDevice(id: "aa:bb:cc:dd:ee:03", name: "Work laptop", ipAddress: "192.168.1.18",
                      macAddress: "aa:bb:cc:dd:ee:03", deviceType: "laptop", isOnline: true,
                      connectionType: "wireless", ssid: "Nighthawk-5G", linkSpeed: 866, signalStrength: 92),
        NetworkDevice(id: "aa:bb:cc:dd:ee:04", name: "iPhone", ipAddress: "192.168.1.42",
                      macAddress: "aa:bb:cc:dd:ee:04", deviceType: "phone", isOnline: true,
                      connectionType: "wireless", ssid: "Nighthawk-5G", linkSpeed: 780, signalStrength: 64),
        NetworkDevice(id: "aa:bb:cc:dd:ee:05", name: "Xbox Series X", ipAddress: "192.168.1.27",
                      macAddress: "aa:bb:cc:dd:ee:05", deviceType: "xbox", isOnline: false,
                      connectionType: "wired"),
        NetworkDevice(id: "aa:bb:cc:dd:ee:06", name: "Guest tablet", ipAddress: "192.168.1.55",
                      macAddress: "aa:bb:cc:dd:ee:06", deviceType: "tablet", isOnline: false,
                      isBlocked: true, connectionType: "wireless", ssid: "Nighthawk-2G")
    ]

    private var rules: [TrafficRule] = [
        TrafficRule(id: "rule-1", name: "Block ads on the TV", action: .block,
                    deviceID: "aa:bb:cc:dd:ee:02", categories: ["Advertising"], order: 0),
        TrafficRule(id: "rule-2", name: "Homework hours", isEnabled: false, action: .reject,
                    deviceID: "aa:bb:cc:dd:ee:06", categories: ["Social media", "Streaming"], order: 1),
        TrafficRule(id: "rule-3", name: "Always allow console traffic", action: .allow,
                    deviceID: "aa:bb:cc:dd:ee:01", services: ["PSN"], order: 2)
    ]

    /// Counters advance on each poll so the dashboard chart animates in demo mode.
    private var receivedBytes: Double = 812_000_000
    private var transmittedBytes: Double = 96_000_000
    private var uptime: TimeInterval = 412_338

    public init() {}

    public func connect(using credentials: RouterCredentials) async throws -> SystemInfo {
        try await Task.sleep(nanoseconds: 250_000_000)
        return systemInfo()
    }

    public func fetchDashboard() async throws -> DashboardSnapshot {
        // 40 Mbps down / 6 Mbps up, jittered, so successive polls differ.
        receivedBytes += Double.random(in: 3_000_000...7_000_000)
        transmittedBytes += Double.random(in: 400_000...900_000)
        uptime += 5

        return DashboardSnapshot(
            systemInfo: systemInfo(),
            cpu: CPUInfo(coreUsage: [Double.random(in: 0.05...0.45), Double.random(in: 0.05...0.35)]),
            memory: StorageInfo(totalBytes: 512 * 1024 * 1024, usedBytes: Double.random(in: 240...320) * 1024 * 1024),
            flash: StorageInfo(totalBytes: 128 * 1024 * 1024, usedBytes: 71 * 1024 * 1024),
            network: NetworkStatistics(
                wanIPAddress: "203.0.113.47",
                receivedBytes: receivedBytes,
                transmittedBytes: transmittedBytes,
                receivedPackets: receivedBytes / 1200,
                transmittedPackets: transmittedBytes / 900,
                receivedDropped: 12,
                transmittedDropped: 3
            ),
            onlineDeviceCount: devices.filter(\.isOnline).count,
            capturedAt: Date()
        )
    }

    private func systemInfo() -> SystemInfo {
        SystemInfo(
            model: "XR500",
            boardName: "Netgear Nighthawk Pro Gaming XR500",
            platform: "BROADCOM",
            firmwareVersion: "2.3.2.114",
            dumaOSVersion: "3.0.128",
            uptime: uptime,
            loadAverage: [0.24, 0.31, 0.28],
            routerDate: ISO8601DateFormatter().string(from: Date())
        )
    }

    // MARK: - Devices

    public func fetchDevices() async throws -> [NetworkDevice] { devices }

    public func rename(deviceID: String, to name: String) async throws {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].name = name
    }

    public func setBlocked(_ blocked: Bool, deviceID: String) async throws {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].isBlocked = blocked
    }

    // MARK: - Geo-Filter

    public func fetchGeoFilter() async throws -> GeoFilterSnapshot { geo }

    public func setGeoFilterMode(_ mode: GeoFilterMode) async throws { geo.settings.mode = mode }

    public func setGeoFilterStrictMode(_ enabled: Bool) async throws { geo.settings.strictMode = enabled }

    public func setGeoFilterRadius(kilometers: Double) async throws {
        geo.settings.radiusKilometers = kilometers
    }

    public func setPingAssist(milliseconds: Double) async throws {
        geo.settings.pingAssistMilliseconds = milliseconds
    }

    public func setGeoFilterHome(latitude: Double, longitude: Double) async throws {
        geo.settings.homeLatitude = latitude
        geo.settings.homeLongitude = longitude
    }

    // MARK: - Congestion Control

    public func fetchQoS() async throws -> QoSSnapshot { qos }

    public func setBandwidth(_ bandwidth: BandwidthSettings) async throws { qos.bandwidth = bandwidth }

    public func setThrottle(_ throttle: ThrottleSettings) async throws { qos.throttle = throttle }

    public func setHardwareAcceleration(_ enabled: Bool) async throws {
        qos.hardwareAccelerationEnabled = enabled
    }

    public func setAllocations(_ allocations: [BandwidthAllocation]) async throws {
        qos.allocations = allocations
    }

    // MARK: - Traffic Controller

    public func fetchTrafficRules() async throws -> [TrafficRule] { rules }

    public func setTrafficRuleEnabled(_ enabled: Bool, ruleID: String) async throws {
        guard let index = rules.firstIndex(where: { $0.id == ruleID }) else { return }
        rules[index].isEnabled = enabled
    }

    public func deleteTrafficRule(ruleID: String) async throws {
        rules.removeAll { $0.id == ruleID }
    }

    // MARK: - System

    public func reboot() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        uptime = 0
    }

    public func rawRPC(package: String, method: String, params: [JSONValue]) async throws -> [JSONValue] {
        [.object([
            "demo": .bool(true),
            "package": .string(package),
            "method": .string(method),
            "params": .array(params)
        ])]
    }
}
