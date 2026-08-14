import Foundation

/// Package identifiers of the DumaOS R-Apps this client talks to.
///
/// DumaOS routes RPC by package: every call is a POST to
/// `/apps/<package-id>/rpc/`. The identifiers below are taken from the DumaOS
/// application bundle shipped on XR-series firmware.
public enum DumaPackage {
    public static let systemInfo = "com.netdumasoftware.systeminfo"
    public static let deviceManager = "com.netdumasoftware.devicemanager"
    public static let geoFilter = "com.netdumasoftware.geofilter"
    public static let qos = "com.netdumasoftware.qos"
    public static let trafficController = "com.netdumasoftware.trafficcontroller"
    public static let networkMonitor = "com.netdumasoftware.networkmonitor"
    public static let adBlocker = "com.netdumasoftware.adblocker"
    public static let benchmark = "com.netdumasoftware.benchmark"
    public static let pingHeatmap = "com.netdumasoftware.pingheatmap"
}

/// Transport for the DumaOS JSON-RPC 2.0 API.
///
/// Wire format, as implemented by the router's own web client (`/nd-js/rpc.js`):
///
/// ```
/// POST /apps/com.netdumasoftware.systeminfo/rpc/
/// Content-Type: application/json-rpc
///
/// {"jsonrpc":"2.0","method":"get_cpu_info","id":1,"params":[]}
/// ```
///
/// `params` is always an array, and a successful `result` is *also* always an
/// array — the browser client spreads it across the callback's arguments. Most
/// procedures therefore return their payload as `result[0]`.
public actor DumaRPCClient {
    private let session: URLSession
    private var credentials: RouterCredentials
    private var nextRequestID = 0

    public init(credentials: RouterCredentials, session: URLSession? = nil) {
        self.credentials = credentials
        self.session = session ?? DumaRPCClient.makeSession()
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        configuration.httpShouldSetCookies = true
        return URLSession(configuration: configuration)
    }

    public func update(credentials: RouterCredentials) {
        self.credentials = credentials
    }

    // MARK: - Calling

    /// Performs an RPC call and returns the whole `result` array.
    @discardableResult
    public func callRaw(
        _ package: String,
        _ method: String,
        _ params: [JSONValue] = []
    ) async throws -> [JSONValue] {
        let request = try makeRequest(package: package, method: method, params: params)

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

        switch http.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw RouterError.unauthorized
        // DumaOS uses these two non-standard statuses to bounce the browser to
        // its login pages; for us they mean "authenticate again".
        case 418, 419:
            throw RouterError.sessionExpired
        case 404:
            throw RouterError.unknownProcedure(package: package, method: method)
        case 500:
            // A 500 still carries a JSON-RPC error body; fall through and decode.
            break
        default:
            throw RouterError.http(status: http.statusCode)
        }

        return try Self.decodeEnvelope(data, package: package, method: method)
    }

    /// Performs an RPC call and decodes `result[index]` into `type`.
    public func call<T: Decodable>(
        _ package: String,
        _ method: String,
        _ params: [JSONValue] = [],
        as type: T.Type,
        at index: Int = 0
    ) async throws -> T {
        let result = try await callRaw(package, method, params)
        guard result.indices.contains(index) else {
            throw RouterError.malformedResponse("\(method) returned \(result.count) value(s)")
        }
        do {
            return try result[index].decode(as: T.self)
        } catch {
            throw RouterError.malformedResponse("could not decode \(method): \(error)")
        }
    }

    /// Performs an RPC call and returns `result[index]` untyped.
    public func callValue(
        _ package: String,
        _ method: String,
        _ params: [JSONValue] = [],
        at index: Int = 0
    ) async throws -> JSONValue {
        let result = try await callRaw(package, method, params)
        guard result.indices.contains(index) else {
            throw RouterError.malformedResponse("\(method) returned \(result.count) value(s)")
        }
        return result[index]
    }

    // MARK: - Request building

    private func makeRequest(package: String, method: String, params: [JSONValue]) throws -> URLRequest {
        guard let base = credentials.webBaseURL,
              let url = URL(string: "apps/\(package)/rpc/", relativeTo: base) else {
            throw RouterError.invalidConfiguration(credentials.trimmedHost)
        }

        nextRequestID += 1
        let body = RPCRequestBody(method: method, id: nextRequestID, params: params)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json-rpc", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let auth = credentials.basicAuthHeader {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    // MARK: - Response decoding

    /// Exposed for testing: turns a raw DumaOS response body into the `result`
    /// array, or throws the error the router described.
    static func decodeEnvelope(_ data: Data, package: String, method: String) throws -> [JSONValue] {
        let envelope: RPCResponseBody
        do {
            envelope = try JSONDecoder().decode(RPCResponseBody.self, from: data)
        } catch {
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
            throw RouterError.malformedResponse(preview)
        }

        // DumaOS signals failure with an `eid`/`msg` pair, sometimes alongside
        // HTTP 200. `error` carries a JSON-RPC style numeric code.
        if envelope.eid != nil || envelope.msg != nil {
            let code = envelope.error?.intValue ?? -32000
            let message = envelope.msg ?? "The router reported an error."
            if code == -32604 { throw RouterError.unauthorized }
            throw RouterError.rpc(code: code, id: envelope.eid, message: message)
        }

        if let error = envelope.error, !error.isNull, error.objectValue != nil {
            let object = error.objectValue ?? [:]
            let code = object["code"]?.intValue ?? -32000
            let message = object["message"]?.stringValue ?? "The router reported an error."
            throw RouterError.rpc(code: code, id: nil, message: message)
        }

        guard let result = envelope.result else {
            throw RouterError.malformedResponse("\(package).\(method) returned no result")
        }

        // Procedures conventionally return an array, but tolerate scalars.
        return result.arrayValue ?? [result]
    }
}

// MARK: - Wire types

struct RPCRequestBody: Encodable {
    let jsonrpc = "2.0"
    let method: String
    let id: Int
    let params: [JSONValue]

    private enum CodingKeys: String, CodingKey {
        case jsonrpc, method, id, params
    }
}

struct RPCResponseBody: Decodable {
    let id: JSONValue?
    let result: JSONValue?
    let error: JSONValue?
    let eid: String?
    let msg: String?
}
