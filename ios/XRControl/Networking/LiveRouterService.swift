import Foundation

/// Talks to a real XR500.
///
/// ## Which API does what
///
/// * **DumaOS JSON-RPC** (`/apps/<package>/rpc/`) owns everything DumaOS added:
///   Geo-Filter, Congestion Control, Traffic Controller, Device Manager and the
///   system dashboard.
/// * **NETGEAR SOAP** (`:5000/soap/server_sa/`) fills in the link-layer detail
///   DumaOS does not expose — Wi-Fi signal strength and link rate — and is the
///   fallback path for reboot.
///
/// ## Getter/setter procedures
///
/// Many DumaOS procedures are dual-purpose: calling them with an empty `params`
/// array reads the current value, and calling them with one argument writes it.
/// `mode`, `strict`, `distance` and `pingass` in the Geo-Filter package all
/// follow this convention, mirroring the router's own web client.
/// Runs an optional sub-request, swallowing failures so a partially available
/// router still renders. Declared outside the actor so it can be used from the
/// concurrent child tasks that `async let` creates.
private func optional<T>(_ work: () async throws -> T) async -> T? {
    try? await work()
}

public actor LiveRouterService: RouterServicing {
    private var credentials: RouterCredentials
    private let rpc: DumaRPCClient
    private let soap: NetgearSOAPClient

    public init(credentials: RouterCredentials) {
        self.credentials = credentials
        self.rpc = DumaRPCClient(credentials: credentials)
        self.soap = NetgearSOAPClient(credentials: credentials)
    }

    // MARK: - Connection

    public func connect(using credentials: RouterCredentials) async throws -> SystemInfo {
        self.credentials = credentials
        await rpc.update(credentials: credentials)
        await soap.update(credentials: credentials)

        let payload = try await rpc.callValue(DumaPackage.systemInfo, "get_system_info")
        return SystemInfo(json: payload)
    }

    // MARK: - Dashboard

    public func fetchDashboard() async throws -> DashboardSnapshot {
        // `get_system_info` is the liveness probe: if it fails, the whole poll
        // fails and the UI can show a connection error. The rest are optional so
        // one unavailable R-App does not blank the dashboard.
        let systemPayload = try await rpc.callValue(DumaPackage.systemInfo, "get_system_info")

        async let cpuPayload = optional { try await self.rpc.callValue(DumaPackage.systemInfo, "get_cpu_info") }
        async let ramPayload = optional { try await self.rpc.callValue(DumaPackage.systemInfo, "get_ram_info") }
        async let flashPayload = optional { try await self.rpc.callValue(DumaPackage.systemInfo, "get_flash_info") }
        async let netPayload = optional { try await self.rpc.callValue(DumaPackage.systemInfo, "get_network_statistics") }
        async let devices = optional { try await self.fetchDevices() }

        return DashboardSnapshot(
            systemInfo: SystemInfo(json: systemPayload),
            cpu: await cpuPayload.map(CPUInfo.init(json:)) ?? CPUInfo(),
            // DumaOS reports memory in kilobytes.
            memory: await ramPayload.map { StorageInfo(json: $0, scale: 1024) } ?? StorageInfo(),
            flash: await flashPayload.map { StorageInfo(json: $0, scale: 1024) } ?? StorageInfo(),
            network: await netPayload.map(NetworkStatistics.init(json:)) ?? NetworkStatistics(),
            onlineDeviceCount: await (devices ?? []).filter(\.isOnline).count,
            capturedAt: Date()
        )
    }

    // MARK: - Devices

    public func fetchDevices() async throws -> [NetworkDevice] {
        let result = try await rpc.callRaw(DumaPackage.deviceManager, "get_all_devices")
        let devices = Self.listPayload(result).compactMap(NetworkDevice.init(dumaJSON:))

        // Signal strength and link rate only exist on the SOAP side; a failure
        // here should never cost us the device list.
        guard let attached = await optional({ try await self.fetchAttachedDevicesOverSOAP() }) else {
            return devices.sorted(by: Self.deviceOrdering)
        }

        let byMAC = Dictionary(
            attached.compactMap { device -> (String, NetworkDevice)? in
                guard let mac = device.macAddress?.uppercased() else { return nil }
                return (mac, device)
            },
            uniquingKeysWith: { first, _ in first }
        )

        let merged = devices.map { device -> NetworkDevice in
            guard let mac = device.macAddress?.uppercased(), let match = byMAC[mac] else { return device }
            return device.merging(soap: match)
        }
        return merged.sorted(by: Self.deviceOrdering)
    }

    private func fetchAttachedDevicesOverSOAP() async throws -> [NetworkDevice] {
        let tree = try await soap.send(service: .deviceInfo, method: "GetAttachDevice2")
        return tree.descendants(named: "Device").compactMap(NetworkDevice.init(soapNode:))
    }

    public func rename(deviceID: String, to name: String) async throws {
        _ = try await rpc.callRaw(
            DumaPackage.deviceManager,
            "set_device_name",
            [.string(deviceID), .string(name)]
        )
    }

    public func setBlocked(_ blocked: Bool, deviceID: String) async throws {
        _ = try await rpc.callRaw(
            DumaPackage.deviceManager,
            "block_device",
            [.string(deviceID), .bool(blocked)]
        )
    }

    // MARK: - Geo-Filter

    public func fetchGeoFilter() async throws -> GeoFilterSnapshot {
        async let modeValue = optional { try await self.rpc.callValue(DumaPackage.geoFilter, "mode") }
        async let strictValue = optional { try await self.rpc.callValue(DumaPackage.geoFilter, "strict") }
        async let distanceValue = optional { try await self.rpc.callValue(DumaPackage.geoFilter, "distance") }
        async let pingAssistValue = optional { try await self.rpc.callValue(DumaPackage.geoFilter, "pingass") }
        async let homeValue = optional { try await self.rpc.callValue(DumaPackage.geoFilter, "home") }
        async let hostsResult = optional { try await self.rpc.callRaw(DumaPackage.geoFilter, "get_all_hosts") }

        var settings = GeoFilterSettings()
        if let raw = await modeValue {
            settings.mode = GeoFilterMode(rawValue: raw.intValue ?? 0) ?? .spectating
        }
        settings.strictMode = await strictValue?.boolValue ?? false
        // `distance` is stored in metres by the R-App.
        if let distance = await distanceValue?.doubleValue {
            settings.radiusKilometers = distance > 5_000 ? distance / 1000 : distance
        }
        settings.pingAssistMilliseconds = await pingAssistValue?.doubleValue ?? 0
        if let home = await homeValue {
            settings.homeLatitude = home["lat"]?.doubleValue
                ?? home["latitude"]?.doubleValue
                ?? home[0]?.doubleValue
                ?? settings.homeLatitude
            settings.homeLongitude = home["long"]?.doubleValue
                ?? home["lon"]?.doubleValue
                ?? home["longitude"]?.doubleValue
                ?? home[1]?.doubleValue
                ?? settings.homeLongitude
        }

        let peers = Self.listPayload(await hostsResult ?? []).compactMap(GeoPeer.init(json:))
        return GeoFilterSnapshot(settings: settings, peers: peers)
    }

    public func setGeoFilterMode(_ mode: GeoFilterMode) async throws {
        _ = try await rpc.callRaw(DumaPackage.geoFilter, "mode", [.number(Double(mode.rawValue))])
    }

    public func setGeoFilterStrictMode(_ enabled: Bool) async throws {
        _ = try await rpc.callRaw(DumaPackage.geoFilter, "strict", [.bool(enabled)])
    }

    public func setGeoFilterRadius(kilometers: Double) async throws {
        _ = try await rpc.callRaw(DumaPackage.geoFilter, "distance", [.number(kilometers * 1000)])
    }

    public func setPingAssist(milliseconds: Double) async throws {
        _ = try await rpc.callRaw(DumaPackage.geoFilter, "pingass", [.number(milliseconds)])
    }

    public func setGeoFilterHome(latitude: Double, longitude: Double) async throws {
        _ = try await rpc.callRaw(
            DumaPackage.geoFilter,
            "home",
            [.object(["lat": .number(latitude), "long": .number(longitude)])]
        )
    }

    // MARK: - Congestion Control

    public func fetchQoS() async throws -> QoSSnapshot {
        async let bandwidthValue = optional { try await self.rpc.callValue(DumaPackage.qos, "get_bandwidth") }
        async let throttleValue = optional { try await self.rpc.callValue(DumaPackage.qos, "get_link_throttle") }
        async let treeValue = optional { try await self.rpc.callValue(DumaPackage.qos, "get_bandwidth_dist_tree") }
        async let servicesResult = optional { try await self.rpc.callRaw(DumaPackage.qos, "get_hyperlane_services") }
        async let accelerationValue = optional { try await self.rpc.callValue(DumaPackage.qos, "get_acceleration") }
        async let devices = optional { try await self.fetchDevices() }

        var bandwidth = BandwidthSettings()
        if let raw = await bandwidthValue {
            let down = raw["down"]?.doubleValue ?? raw["downband"]?.doubleValue ?? raw[0]?.doubleValue ?? 0
            let up = raw["up"]?.doubleValue ?? raw["upband"]?.doubleValue ?? raw[1]?.doubleValue ?? 0
            bandwidth = BandwidthSettings(downKbps: down, upKbps: up)
        }

        let names = Dictionary(
            (await devices ?? []).map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        return QoSSnapshot(
            bandwidth: bandwidth,
            throttle: await throttleValue.map(ThrottleSettings.init(json:)) ?? ThrottleSettings(),
            allocations: await treeValue.map { BandwidthAllocation.flatten($0, deviceNames: names) } ?? [],
            services: Self.listPayload(await servicesResult ?? []).compactMap(HyperlaneService.init(json:)),
            hardwareAccelerationEnabled: await accelerationValue?.boolValue ?? false
        )
    }

    public func setBandwidth(_ bandwidth: BandwidthSettings) async throws {
        _ = try await rpc.callRaw(
            DumaPackage.qos,
            "set_bandwidth",
            [.number(bandwidth.downKbps), .number(bandwidth.upKbps)]
        )
    }

    public func setThrottle(_ throttle: ThrottleSettings) async throws {
        _ = try await rpc.callRaw(
            DumaPackage.qos,
            "set_link_throttle",
            [.object([
                "enabled": .bool(throttle.isEnabled),
                "dthrottle": .number(throttle.downstreamFraction),
                "uthrottle": .number(throttle.upstreamFraction)
            ])]
        )
    }

    public func setHardwareAcceleration(_ enabled: Bool) async throws {
        _ = try await rpc.callRaw(DumaPackage.qos, "set_acceleration", [.bool(enabled)])
    }

    public func setAllocations(_ allocations: [BandwidthAllocation]) async throws {
        let children = allocations.map { allocation in
            JSONValue.object([
                "devid": .string(allocation.id),
                "down_normprop": .number(allocation.downstreamShare),
                "up_normprop": .number(allocation.upstreamShare),
                "share_excess": .bool(allocation.sharesExcess),
                "children": .array([])
            ])
        }
        _ = try await rpc.callRaw(
            DumaPackage.qos,
            "set_bandwidth_dist_tree",
            [.object(["children": .array(children)])]
        )
    }

    // MARK: - Traffic Controller

    public func fetchTrafficRules() async throws -> [TrafficRule] {
        let result = try await rpc.callRaw(DumaPackage.trafficController, "get_rules")
        return Self.listPayload(result).enumerated().compactMap { index, value in
            TrafficRule(json: value, order: index)
        }
    }

    public func setTrafficRuleEnabled(_ enabled: Bool, ruleID: String) async throws {
        _ = try await rpc.callRaw(
            DumaPackage.trafficController,
            "update_rule",
            [.string(ruleID), .object(["enabled": .bool(enabled)])]
        )
    }

    public func deleteTrafficRule(ruleID: String) async throws {
        _ = try await rpc.callRaw(DumaPackage.trafficController, "delete_rule", [.string(ruleID)])
    }

    // MARK: - System

    public func reboot() async throws {
        do {
            _ = try await rpc.callRaw(DumaPackage.systemInfo, "reboot")
        } catch {
            // Some firmware revisions only reboot through the SOAP API.
            _ = try await soap.send(service: .deviceConfig, method: "Reboot")
        }
    }

    public func rawRPC(package: String, method: String, params: [JSONValue]) async throws -> [JSONValue] {
        try await rpc.callRaw(package, method, params)
    }

    // MARK: - Helpers

    /// DumaOS procedures return their payload inside the JSON-RPC `result`
    /// array. Collection-returning procedures put the collection at `result[0]`,
    /// but a few flatten it into `result` itself.
    static func listPayload(_ result: [JSONValue]) -> [JSONValue] {
        if result.count == 1, let inner = result[0].arrayValue { return inner }
        if result.count == 1, let object = result[0].objectValue {
            // `{ "1": {...}, "2": {...} }` — a Lua table with numeric keys.
            let sorted = object.sorted { lhs, rhs in
                (Int(lhs.key) ?? .max) < (Int(rhs.key) ?? .max)
            }
            if sorted.allSatisfy({ $0.value.objectValue != nil }) {
                return sorted.map(\.value)
            }
            return [result[0]]
        }
        return result
    }

    private static func deviceOrdering(_ lhs: NetworkDevice, _ rhs: NetworkDevice) -> Bool {
        if lhs.isOnline != rhs.isOnline { return lhs.isOnline }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
