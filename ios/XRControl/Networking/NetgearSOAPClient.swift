import Foundation

/// NETGEAR SOAP services used by the XR500 firmware.
public enum SOAPService: String {
    case deviceInfo = "DeviceInfo:1"
    case deviceConfig = "DeviceConfig:1"
    case parentalControl = "ParentalControl:1"
    case wanIPConnection = "WANIPConnection:1"
    case wanEthernetLinkConfig = "WANEthernetLinkConfig:1"
    case wlanConfiguration = "WLANConfiguration:1"
    case advancedQoS = "AdvancedQoS:1"

    var urn: String { "urn:NETGEAR-ROUTER:service:\(rawValue)" }
}

/// Client for the (undocumented, reverse-engineered) NETGEAR SOAP API that runs
/// alongside DumaOS on port 5000.
///
/// It complements the DumaOS RPC API: DumaOS owns the gaming features, while
/// SOAP owns firmware-level operations such as reboot, the attached-device
/// table and the traffic meter.
public actor NetgearSOAPClient {
    /// NETGEAR firmware accepts any session ID as long as it is echoed back on
    /// every call; the router's own web client hardcodes one too.
    static let sessionID = "A7D88AE69687E58D9A00"

    private let session: URLSession
    private var credentials: RouterCredentials
    private var isAuthenticated = false

    public init(credentials: RouterCredentials, session: URLSession? = nil) {
        self.credentials = credentials
        self.session = session ?? NetgearSOAPClient.makeSession()
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        configuration.httpShouldSetCookies = true
        return URLSession(configuration: configuration)
    }

    public func update(credentials: RouterCredentials) {
        self.credentials = credentials
        isAuthenticated = false
    }

    // MARK: - Authentication

    /// Signs in. Newer firmware uses `DeviceConfig:1#SOAPLogin`; older builds
    /// only understand `ParentalControl:1#Authenticate`, so both are attempted.
    public func login() async throws {
        let modern = try? await send(
            service: .deviceConfig,
            method: "SOAPLogin",
            parameters: [("Username", credentials.username), ("Password", credentials.password)],
            requiresAuthentication: false
        )
        if modern != nil {
            isAuthenticated = true
            return
        }

        _ = try await send(
            service: .parentalControl,
            method: "Authenticate",
            parameters: [("NewUsername", credentials.username), ("NewPassword", credentials.password)],
            requiresAuthentication: false
        )
        isAuthenticated = true
    }

    private func ensureAuthenticated() async throws {
        guard !isAuthenticated else { return }
        try await login()
    }

    // MARK: - Calls

    /// Sends a SOAP request and returns the parsed response tree.
    @discardableResult
    public func send(
        service: SOAPService,
        method: String,
        parameters: [(String, String)] = [],
        requiresAuthentication: Bool = true
    ) async throws -> XMLNode {
        if requiresAuthentication {
            try await ensureAuthenticated()
        }

        guard let base = credentials.soapBaseURL,
              let url = URL(string: "soap/server_sa/", relativeTo: base) else {
            throw RouterError.invalidConfiguration(credentials.trimmedHost)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\(service.urn)#\(method)", forHTTPHeaderField: "SOAPAction")
        request.setValue("text/xml", forHTTPHeaderField: "Accept")
        request.httpBody = Data(Self.envelope(service: service, method: method, parameters: parameters).utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RouterError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw RouterError.malformedResponse("no HTTP response")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            isAuthenticated = false
            throw RouterError.unauthorized
        }
        guard (200...299).contains(http.statusCode) || http.statusCode == 500 else {
            throw RouterError.http(status: http.statusCode)
        }

        let tree = try XMLTreeParser.parse(data)
        try Self.validateResponseCode(in: tree)
        return tree
    }

    /// Builds a SOAP 1.1 envelope in the dialect NETGEAR firmware expects.
    static func envelope(service: SOAPService, method: String, parameters: [(String, String)]) -> String {
        let body = parameters
            .map { "<\($0.0)>\(escape($0.1))</\($0.0)>" }
            .joined()

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" \
        xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" \
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" \
        xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <SOAP-ENV:Header><SessionID>\(sessionID)</SessionID></SOAP-ENV:Header>
        <SOAP-ENV:Body><M1:\(method) xmlns:M1="\(service.urn)">\(body)</M1:\(method)></SOAP-ENV:Body>
        </SOAP-ENV:Envelope>
        """
    }

    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    /// NETGEAR reports success as `<ResponseCode>000</ResponseCode>`; `401`
    /// means the session is not authenticated.
    static func validateResponseCode(in tree: XMLNode) throws {
        guard let code = tree.value("ResponseCode") else { return }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized == "000" || normalized == "0" { return }
        if normalized == "401" { throw RouterError.unauthorized }
        throw RouterError.soap(code: normalized)
    }
}
