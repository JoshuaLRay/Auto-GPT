import Foundation

/// A device on the LAN.
///
/// Merges two sources: DumaOS `devicemanager.get_all_devices` (which owns the
/// friendly name, device type and blocked flag) and the NETGEAR SOAP
/// `GetAttachDevice2` table (which owns link speed and signal strength).
public struct NetworkDevice: Identifiable, Equatable {
    public var id: String
    public var name: String
    public var ipAddress: String?
    public var macAddress: String?
    public var deviceType: String
    public var isOnline: Bool
    public var isBlocked: Bool
    public var connectionType: String?
    public var ssid: String?
    /// Megabits per second, when the router reports a link rate.
    public var linkSpeed: Double?
    /// 0...100, wireless only.
    public var signalStrength: Double?
    /// The untouched RPC payload, shown in the device detail screen so unknown
    /// firmware fields are still visible.
    public var raw: JSONValue?

    public init(
        id: String,
        name: String,
        ipAddress: String? = nil,
        macAddress: String? = nil,
        deviceType: String = "other",
        isOnline: Bool = false,
        isBlocked: Bool = false,
        connectionType: String? = nil,
        ssid: String? = nil,
        linkSpeed: Double? = nil,
        signalStrength: Double? = nil,
        raw: JSONValue? = nil
    ) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.deviceType = deviceType
        self.isOnline = isOnline
        self.isBlocked = isBlocked
        self.connectionType = connectionType
        self.ssid = ssid
        self.linkSpeed = linkSpeed
        self.signalStrength = signalStrength
        self.raw = raw
    }

    /// Parses one entry of `devicemanager.get_all_devices`.
    ///
    /// Field names vary between DumaOS builds, so each property tries the
    /// spellings observed in the shipped R-App before giving up.
    public init?(dumaJSON json: JSONValue) {
        guard let object = json.objectValue else { return nil }

        let identifier = json["id"]?.stringValue
            ?? json["devid"]?.stringValue
            ?? json["mac"]?.stringValue
            ?? json["mac_address"]?.stringValue
        guard let identifier, !identifier.isEmpty else { return nil }

        let interfaces = json["interfaces"]?.arrayValue ?? []
        let primaryInterface = interfaces.first

        let ip = json["ip"]?.stringValue
            ?? json["ip_address"]?.stringValue
            ?? primaryInterface?["ip"]?.stringValue
            ?? primaryInterface?["ip_address"]?.stringValue

        let mac = json["mac"]?.stringValue
            ?? json["mac_address"]?.stringValue
            ?? primaryInterface?["mac"]?.stringValue

        // `state`/`status` are truthy strings ("online") on some builds and
        // booleans on others.
        let onlineFlag = json["online"]?.boolValue
            ?? json["connected"]?.boolValue
            ?? primaryInterface?["online"]?.boolValue
        let stateText = (json["state"]?.stringValue ?? json["status"]?.stringValue)?.lowercased()
        let online = onlineFlag ?? (stateText.map { $0 == "online" || $0 == "connected" || $0 == "up" } ?? false)

        self.init(
            id: identifier,
            name: json["name"]?.stringValue
                ?? json["hostname"]?.stringValue
                ?? ip
                ?? identifier,
            ipAddress: ip,
            macAddress: mac,
            deviceType: json["type"]?.stringValue ?? json["device_type"]?.stringValue ?? "other",
            isOnline: online,
            isBlocked: json["blocked"]?.boolValue ?? json["block"]?.boolValue ?? false,
            connectionType: primaryInterface?["type"]?.stringValue
                ?? json["connection_type"]?.stringValue,
            ssid: primaryInterface?["ssid"]?.stringValue ?? json["ssid"]?.stringValue,
            raw: .object(object)
        )
    }

    /// Parses one `<Device>` element of a SOAP `GetAttachDevice2` response.
    public init?(soapNode node: XMLNode) {
        guard let mac = node.value("MAC") ?? node.value("MACAddress") else { return nil }
        let name = node.value("Name") ?? node.value("NameUserSet") ?? mac
        self.init(
            id: mac,
            name: name == "--" ? (node.value("IP") ?? mac) : name,
            ipAddress: node.value("IP"),
            macAddress: mac,
            deviceType: node.value("DeviceType") ?? "other",
            isOnline: true,
            isBlocked: node.value("AllowOrBlock")?.caseInsensitiveCompare("Block") == .orderedSame,
            connectionType: node.value("ConnectionType"),
            ssid: node.value("SSID"),
            linkSpeed: node.value("Linkspeed").flatMap(Double.init),
            signalStrength: node.value("SignalStrength").flatMap(Double.init)
        )
    }

    /// Overlays link-layer detail from the SOAP table onto a DumaOS device.
    public func merging(soap other: NetworkDevice) -> NetworkDevice {
        var merged = self
        merged.linkSpeed = merged.linkSpeed ?? other.linkSpeed
        merged.signalStrength = merged.signalStrength ?? other.signalStrength
        merged.connectionType = merged.connectionType ?? other.connectionType
        merged.ssid = merged.ssid ?? other.ssid
        merged.ipAddress = merged.ipAddress ?? other.ipAddress
        return merged
    }

    /// SF Symbol chosen from the DumaOS device-type vocabulary.
    public var symbolName: String {
        switch deviceType.lowercased() {
        case "playstation", "xbox", "nintendoswitch", "nintendo_wii", "nintendo_ds":
            return "gamecontroller.fill"
        case "phone", "voip_phone":
            return "iphone"
        case "tablet":
            return "ipad"
        case "computer", "laptop":
            return "laptopcomputer"
        case "printer", "scanner":
            return "printer.fill"
        case "camera", "security_camera", "arlo":
            return "video.fill"
        case "tv", "set_top_box", "dvd_player", "media_device":
            return "tv.fill"
        case "speaker", "av_receiver", "amazon_echo", "google_home":
            return "hifispeaker.fill"
        case "thermostat", "smart_home_device":
            return "house.fill"
        case "extender", "router":
            return "wifi.router.fill"
        default:
            return "desktopcomputer"
        }
    }

    /// Normalised connection description for the device list.
    public var connectionDescription: String {
        guard let connectionType, !connectionType.isEmpty else {
            return isOnline ? "Connected" : "Offline"
        }
        if connectionType.lowercased().contains("wire") { return "Wired" }
        if let ssid, !ssid.isEmpty { return ssid }
        return connectionType
    }
}

/// A device type the router understands, from `devicemanager.get_types`.
public struct DeviceTypeOption: Identifiable, Equatable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}
