import Foundation
import Security

/// Persists router credentials. The password lives in the keychain; everything
/// else (host, ports, username) lives in `UserDefaults` so the connection form
/// can be repopulated without prompting for keychain access.
public struct CredentialStore {
    private let service: String
    private let account: String
    private let defaults: UserDefaults

    private enum Key {
        static let host = "router.host"
        static let username = "router.username"
        static let webPort = "router.webPort"
        static let soapPort = "router.soapPort"
        static let useHTTPS = "router.useHTTPS"
        static let hasSavedCredentials = "router.hasSavedCredentials"
    }

    public init(
        service: String = "com.xrcontrol.router",
        account: String = "primary",
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.account = account
        self.defaults = defaults
    }

    public var hasSavedCredentials: Bool {
        defaults.bool(forKey: Key.hasSavedCredentials)
    }

    public func load() -> RouterCredentials? {
        guard hasSavedCredentials else { return nil }
        var credentials = RouterCredentials()
        credentials.host = defaults.string(forKey: Key.host) ?? credentials.host
        credentials.username = defaults.string(forKey: Key.username) ?? credentials.username
        if defaults.object(forKey: Key.webPort) != nil {
            credentials.webPort = defaults.integer(forKey: Key.webPort)
        }
        if defaults.object(forKey: Key.soapPort) != nil {
            credentials.soapPort = defaults.integer(forKey: Key.soapPort)
        }
        credentials.useHTTPS = defaults.bool(forKey: Key.useHTTPS)
        credentials.password = readPassword() ?? ""
        return credentials
    }

    public func save(_ credentials: RouterCredentials) {
        defaults.set(credentials.trimmedHost, forKey: Key.host)
        defaults.set(credentials.username, forKey: Key.username)
        defaults.set(credentials.webPort, forKey: Key.webPort)
        defaults.set(credentials.soapPort, forKey: Key.soapPort)
        defaults.set(credentials.useHTTPS, forKey: Key.useHTTPS)
        defaults.set(true, forKey: Key.hasSavedCredentials)
        writePassword(credentials.password)
    }

    public func clear() {
        [Key.host, Key.username, Key.webPort, Key.soapPort, Key.useHTTPS, Key.hasSavedCredentials]
            .forEach { defaults.removeObject(forKey: $0) }
        SecItemDelete(baseQuery() as CFDictionary)
    }

    // MARK: - Keychain

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func readPassword() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func writePassword(_ password: String) {
        let data = Data(password.utf8)
        let query = baseQuery()

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert.merge(attributes) { current, _ in current }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }
}
