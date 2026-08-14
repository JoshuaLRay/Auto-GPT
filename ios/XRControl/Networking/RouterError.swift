import Foundation

/// Errors surfaced by both the DumaOS RPC client and the NETGEAR SOAP client.
public enum RouterError: LocalizedError, Equatable {
    /// Host/port combination could not be turned into a URL.
    case invalidConfiguration(String)
    /// Router refused the credentials (HTTP 401/403, or SOAP response code 401).
    case unauthorized
    /// DumaOS answered with a "log in again" redirect status (418/419).
    case sessionExpired
    /// The requested RPC procedure does not exist on this firmware.
    case unknownProcedure(package: String, method: String)
    /// The router replied but the payload was not the expected shape.
    case malformedResponse(String)
    /// A DumaOS RPC error object, e.g. `ERROR_UBUS` when an R-App is not loaded.
    case rpc(code: Int, id: String?, message: String)
    /// A NETGEAR SOAP call returned a non-zero `ResponseCode`.
    case soap(code: String)
    /// Any unexpected HTTP status.
    case http(status: Int)
    /// Transport-level failure (timeout, no route to host, …).
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let detail):
            return "Invalid router address: \(detail)"
        case .unauthorized:
            return "The router rejected your username or password."
        case .sessionExpired:
            return "The router signed you out. Sign in again to continue."
        case .unknownProcedure(let package, let method):
            return "This firmware does not provide \(package).\(method)."
        case .malformedResponse(let detail):
            return "Unexpected response from the router: \(detail)"
        case .rpc(_, let id, let message):
            if let id, !id.isEmpty { return "\(id): \(message)" }
            return message
        case .soap(let code):
            return "The router's SOAP API returned error code \(code)."
        case .http(let status):
            return "The router returned HTTP \(status)."
        case .transport(let detail):
            return "Could not reach the router: \(detail)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unauthorized, .sessionExpired:
            return "Check the admin password you use for the router's web interface."
        case .transport:
            return "Make sure you're on the same Wi-Fi network as the router, and that its address is correct."
        case .unknownProcedure:
            return "This feature may need a newer DumaOS version, or the R-App may not be installed."
        case .rpc:
            return "Open the feature in the router's web interface once, then try again."
        default:
            return nil
        }
    }

    /// True when re-authenticating might fix the problem.
    public var isAuthenticationFailure: Bool {
        switch self {
        case .unauthorized, .sessionExpired: return true
        default: return false
        }
    }
}
