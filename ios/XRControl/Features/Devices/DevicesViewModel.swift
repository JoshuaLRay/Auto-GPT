import Foundation
import SwiftUI

@MainActor
final class DevicesViewModel: ObservableObject {
    @Published private(set) var devices: [NetworkDevice] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var showsOfflineDevices = true

    func load(service: RouterServicing) async {
        isLoading = devices.isEmpty
        defer { isLoading = false }
        do {
            devices = try await service.fetchDevices()
            errorMessage = nil
        } catch {
            errorMessage = AppModel.message(for: error)
        }
    }

    var filteredDevices: [NetworkDevice] {
        var result = devices
        if !showsOfflineDevices {
            result = result.filter(\.isOnline)
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return result }
        return result.filter { device in
            device.name.localizedCaseInsensitiveContains(query)
                || (device.ipAddress?.localizedCaseInsensitiveContains(query) ?? false)
                || (device.macAddress?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var onlineCount: Int { devices.filter(\.isOnline).count }

    func rename(_ device: NetworkDevice, to name: String, service: RouterServicing) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != device.name else { return }

        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        let previous = devices[index].name
        devices[index].name = trimmed

        do {
            try await service.rename(deviceID: device.id, to: trimmed)
            errorMessage = nil
        } catch {
            devices[index].name = previous
            errorMessage = AppModel.message(for: error)
        }
    }

    func setBlocked(_ blocked: Bool, device: NetworkDevice, service: RouterServicing) async {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        let previous = devices[index].isBlocked
        devices[index].isBlocked = blocked

        do {
            try await service.setBlocked(blocked, deviceID: device.id)
            errorMessage = nil
        } catch {
            devices[index].isBlocked = previous
            errorMessage = AppModel.message(for: error)
        }
    }

    /// Keeps the detail screen in sync after an edit.
    func device(withID id: String) -> NetworkDevice? {
        devices.first { $0.id == id }
    }
}
