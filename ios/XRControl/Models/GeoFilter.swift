import CoreLocation
import Foundation

/// Geo-Filter operating mode.
///
/// DumaOS stores the mode as a small integer; the R-App's UI exposes it as
/// Spectating (observe only) versus Filtering (enforce the radius).
public enum GeoFilterMode: Int, CaseIterable, Identifiable, Equatable {
    case spectating = 0
    case filtering = 1

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .spectating: return "Spectating"
        case .filtering: return "Filtering"
        }
    }

    public var explanation: String {
        switch self {
        case .spectating:
            return "Shows who you're connecting to without blocking anyone. Use this to learn where servers are before you tighten the radius."
        case .filtering:
            return "Blocks hosts outside your radius. Ping Assist can still allow fast servers beyond the circle."
        }
    }

    public var symbolName: String {
        switch self {
        case .spectating: return "eye"
        case .filtering: return "line.3.horizontal.decrease.circle"
        }
    }
}

/// The Geo-Filter's current configuration.
public struct GeoFilterSettings: Equatable {
    public var mode: GeoFilterMode
    public var strictMode: Bool
    /// Filter radius in kilometres.
    public var radiusKilometers: Double
    /// Ping Assist threshold in milliseconds; 0 disables it.
    public var pingAssistMilliseconds: Double
    public var homeLatitude: Double
    public var homeLongitude: Double

    public init(
        mode: GeoFilterMode = .spectating,
        strictMode: Bool = false,
        radiusKilometers: Double = 800,
        pingAssistMilliseconds: Double = 0,
        homeLatitude: Double = 37.3349,
        homeLongitude: Double = -122.0090
    ) {
        self.mode = mode
        self.strictMode = strictMode
        self.radiusKilometers = radiusKilometers
        self.pingAssistMilliseconds = pingAssistMilliseconds
        self.homeLatitude = homeLatitude
        self.homeLongitude = homeLongitude
    }

    public var homeCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: homeLatitude, longitude: homeLongitude)
    }

    public var radiusMeters: Double { radiusKilometers * 1000 }
}

/// A host the Geo-Filter has seen — a game server or another player's console.
public struct GeoPeer: Identifiable, Equatable {
    public enum Kind: String, Equatable {
        case peer
        case server
        case unknown
    }

    public var id: String
    public var ipAddress: String
    public var latitude: Double
    public var longitude: Double
    public var kind: Kind
    public var isAllowed: Bool
    public var isDenied: Bool
    /// Round-trip time in milliseconds, when known.
    public var pingMilliseconds: Double?
    public var countryName: String?

    public init(
        id: String,
        ipAddress: String,
        latitude: Double,
        longitude: Double,
        kind: Kind = .unknown,
        isAllowed: Bool = false,
        isDenied: Bool = false,
        pingMilliseconds: Double? = nil,
        countryName: String? = nil
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.latitude = latitude
        self.longitude = longitude
        self.kind = kind
        self.isAllowed = isAllowed
        self.isDenied = isDenied
        self.pingMilliseconds = pingMilliseconds
        self.countryName = countryName
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Distance from home in kilometres.
    public func distanceKilometers(from home: CLLocationCoordinate2D) -> Double {
        let a = CLLocation(latitude: home.latitude, longitude: home.longitude)
        let b = CLLocation(latitude: latitude, longitude: longitude)
        return a.distance(from: b) / 1000
    }

    /// Parses a Geo-Filter host entry. Coordinates may arrive as a `location`
    /// object, a flat `lat`/`long` pair, or a two-element array.
    public init?(json: JSONValue) {
        let ip = json["ip"]?.stringValue
            ?? json["address"]?.stringValue
            ?? json["host"]?.stringValue
        guard let ip, !ip.isEmpty else { return nil }

        let location = json["location"] ?? json["geo"] ?? json["coords"]
        let latitude = json["lat"]?.doubleValue
            ?? json["latitude"]?.doubleValue
            ?? location?["lat"]?.doubleValue
            ?? location?["latitude"]?.doubleValue
            ?? location?[0]?.doubleValue
        let longitude = json["long"]?.doubleValue
            ?? json["lon"]?.doubleValue
            ?? json["lng"]?.doubleValue
            ?? json["longitude"]?.doubleValue
            ?? location?["long"]?.doubleValue
            ?? location?["lon"]?.doubleValue
            ?? location?["longitude"]?.doubleValue
            ?? location?[1]?.doubleValue
        guard let latitude, let longitude else { return nil }

        let typeText = (json["type"]?.stringValue ?? json["kind"]?.stringValue)?.lowercased()
        let kind: Kind
        switch typeText {
        case "server", "dedicated", "1": kind = .server
        case "peer", "player", "0": kind = .peer
        default: kind = .unknown
        }

        self.init(
            id: json["id"]?.stringValue ?? ip,
            ipAddress: ip,
            latitude: latitude,
            longitude: longitude,
            kind: kind,
            isAllowed: json["allow"]?.boolValue ?? json["allowed"]?.boolValue ?? false,
            isDenied: json["deny"]?.boolValue ?? json["blocked"]?.boolValue ?? false,
            pingMilliseconds: json["ping"]?.doubleValue ?? json["rtt"]?.doubleValue,
            countryName: json["country"]?.stringValue ?? json["cc"]?.stringValue
        )
    }
}
