import Foundation

/// One poll of everything the dashboard shows.
public struct DashboardSnapshot: Equatable {
    public var systemInfo: SystemInfo
    public var cpu: CPUInfo
    public var memory: StorageInfo
    public var flash: StorageInfo
    public var network: NetworkStatistics
    public var onlineDeviceCount: Int
    public var capturedAt: Date

    public init(
        systemInfo: SystemInfo = SystemInfo(),
        cpu: CPUInfo = CPUInfo(),
        memory: StorageInfo = StorageInfo(),
        flash: StorageInfo = StorageInfo(),
        network: NetworkStatistics = NetworkStatistics(),
        onlineDeviceCount: Int = 0,
        capturedAt: Date = Date()
    ) {
        self.systemInfo = systemInfo
        self.cpu = cpu
        self.memory = memory
        self.flash = flash
        self.network = network
        self.onlineDeviceCount = onlineDeviceCount
        self.capturedAt = capturedAt
    }
}

/// The Geo-Filter screen's data in one value.
public struct GeoFilterSnapshot: Equatable {
    public var settings: GeoFilterSettings
    public var peers: [GeoPeer]

    public init(settings: GeoFilterSettings = GeoFilterSettings(), peers: [GeoPeer] = []) {
        self.settings = settings
        self.peers = peers
    }
}

/// Everything the app can ask a router to do.
///
/// Two implementations exist: `LiveRouterService`, which talks to a real XR500,
/// and `MockRouterService`, which serves canned data for previews, tests, and
/// the in-app demo mode.
public protocol RouterServicing: AnyObject {
    /// Applies new credentials and verifies them, returning firmware identity.
    func connect(using credentials: RouterCredentials) async throws -> SystemInfo

    func fetchDashboard() async throws -> DashboardSnapshot

    func fetchDevices() async throws -> [NetworkDevice]
    func rename(deviceID: String, to name: String) async throws
    func setBlocked(_ blocked: Bool, deviceID: String) async throws

    func fetchGeoFilter() async throws -> GeoFilterSnapshot
    func setGeoFilterMode(_ mode: GeoFilterMode) async throws
    func setGeoFilterStrictMode(_ enabled: Bool) async throws
    func setGeoFilterRadius(kilometers: Double) async throws
    func setPingAssist(milliseconds: Double) async throws
    func setGeoFilterHome(latitude: Double, longitude: Double) async throws

    func fetchQoS() async throws -> QoSSnapshot
    func setBandwidth(_ bandwidth: BandwidthSettings) async throws
    func setThrottle(_ throttle: ThrottleSettings) async throws
    func setHardwareAcceleration(_ enabled: Bool) async throws
    func setAllocations(_ allocations: [BandwidthAllocation]) async throws

    func fetchTrafficRules() async throws -> [TrafficRule]
    func setTrafficRuleEnabled(_ enabled: Bool, ruleID: String) async throws
    func deleteTrafficRule(ruleID: String) async throws

    func reboot() async throws

    /// Escape hatch used by the in-app RPC explorer.
    func rawRPC(package: String, method: String, params: [JSONValue]) async throws -> [JSONValue]
}
