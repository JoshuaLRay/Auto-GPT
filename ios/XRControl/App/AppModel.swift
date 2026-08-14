import Foundation
import SwiftUI

/// Owns the connection to the router and vends the service every screen uses.
@MainActor
public final class AppModel: ObservableObject {
    public enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected(SystemInfo)
        case failed(String)

        public var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }

        public var systemInfo: SystemInfo? {
            if case .connected(let info) = self { return info }
            return nil
        }
    }

    @Published public private(set) var state: ConnectionState = .disconnected
    @Published public var credentials: RouterCredentials
    /// True when the app is running against `MockRouterService`.
    @Published public private(set) var isDemoMode = false
    @Published public var rememberCredentials: Bool

    public private(set) var service: RouterServicing

    private let store: CredentialStore

    public init(store: CredentialStore = CredentialStore()) {
        self.store = store
        let saved = store.load()
        self.credentials = saved ?? RouterCredentials()
        self.rememberCredentials = saved != nil
        self.service = LiveRouterService(credentials: saved ?? RouterCredentials())
    }

    /// Attempts to sign in with the current credentials.
    public func connect() async {
        guard credentials.isComplete else {
            state = .failed("Enter the router's address and admin username.")
            return
        }

        state = .connecting
        isDemoMode = false
        let live = LiveRouterService(credentials: credentials)
        service = live

        do {
            let info = try await live.connect(using: credentials)
            state = .connected(info)
            if rememberCredentials {
                store.save(credentials)
            } else {
                store.clear()
            }
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    /// Signs in against canned data so the interface can be explored offline.
    public func startDemoMode() async {
        state = .connecting
        isDemoMode = true
        let mock = MockRouterService()
        service = mock
        do {
            let info = try await mock.connect(using: credentials)
            state = .connected(info)
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    public func disconnect() {
        state = .disconnected
        isDemoMode = false
        service = LiveRouterService(credentials: credentials)
    }

    public func forgetSavedCredentials() {
        store.clear()
        rememberCredentials = false
        credentials.password = ""
    }

    /// Attempts a silent reconnect when a screen reports an auth failure.
    public func handleAuthenticationFailure() {
        guard !isDemoMode else { return }
        state = .failed("The router signed you out. Sign in again.")
    }

    static func message(for error: Error) -> String {
        guard let routerError = error as? RouterError else { return error.localizedDescription }
        if let suggestion = routerError.recoverySuggestion {
            return "\(routerError.localizedDescription) \(suggestion)"
        }
        return routerError.localizedDescription
    }

    /// A connected, demo-backed model for SwiftUI previews.
    ///
    /// Declared here because `state` and `service` are file-private setters.
    public static var preview: AppModel {
        let model = AppModel(store: CredentialStore(service: "com.xrcontrol.preview"))
        model.service = MockRouterService()
        model.isDemoMode = true
        model.state = .connected(
            SystemInfo(
                model: "XR500",
                boardName: "Netgear Nighthawk Pro Gaming XR500",
                platform: "BROADCOM",
                firmwareVersion: "2.3.2.114",
                dumaOSVersion: "3.0.128",
                uptime: 412_338,
                loadAverage: [0.24, 0.31, 0.28]
            )
        )
        return model
    }
}
