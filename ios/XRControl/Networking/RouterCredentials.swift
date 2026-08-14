import Foundation

/// Connection details for a DumaOS router.
///
/// The XR500 serves two distinct APIs on two ports:
///  - the DumaOS JSON-RPC API on the regular web UI port (80 by default), and
///  - the NETGEAR SOAP API on port 5000.
public struct RouterCredentials: Codable, Equatable, Sendable {
    public var host: String
    public var username: String
    public var password: String
    /// Port serving the DumaOS web UI and its `/apps/<package>/rpc/` endpoints.
    public var webPort: Int
    /// Port serving the NETGEAR SOAP endpoint `/soap/server_sa/`.
    public var soapPort: Int
    /// The XR500 web UI is plain HTTP on the LAN. Enable only if you have
    /// deliberately put a TLS terminator in front of the router.
    public var useHTTPS: Bool

    public init(
        host: String = "192.168.1.1",
        username: String = "admin",
        password: String = "",
        webPort: Int = 80,
        soapPort: Int = 5000,
        useHTTPS: Bool = false
    ) {
        self.host = host
        self.username = username
        self.password = password
        self.webPort = webPort
        self.soapPort = soapPort
        self.useHTTPS = useHTTPS
    }

    public var scheme: String { useHTTPS ? "https" : "http" }

    /// Base URL for the DumaOS web UI / RPC endpoints.
    public var webBaseURL: URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = trimmedHost
        components.port = webPort
        components.path = "/"
        return components.url
    }

    /// Base URL for the NETGEAR SOAP endpoint.
    public var soapBaseURL: URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = trimmedHost
        components.port = soapPort
        components.path = "/"
        return components.url
    }

    public var trimmedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `Authorization: Basic …` header value. The XR500 web server guards the
    /// DumaOS UI (and therefore the RPC endpoints) with HTTP Basic auth.
    public var basicAuthHeader: String? {
        guard let data = "\(username):\(password)".data(using: .utf8) else { return nil }
        return "Basic \(data.base64EncodedString())"
    }

    public var isComplete: Bool {
        !trimmedHost.isEmpty && !username.isEmpty
    }
}
