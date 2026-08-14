import Foundation
import SwiftUI

@MainActor
final class GeoFilterViewModel: ObservableObject {
    @Published var settings = GeoFilterSettings()
    @Published private(set) var peers: [GeoPeer] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// Slider edits are applied locally straight away and pushed to the router
    /// once the user stops moving, so a drag does not fire dozens of RPCs.
    private var pendingRadiusTask: Task<Void, Never>?
    private var pendingPingAssistTask: Task<Void, Never>?
    private let writeDebounce: Duration = .milliseconds(500)

    func load(service: RouterServicing) async {
        isLoading = peers.isEmpty
        defer { isLoading = false }
        do {
            let snapshot = try await service.fetchGeoFilter()
            settings = snapshot.settings
            peers = snapshot.peers
            errorMessage = nil
        } catch {
            errorMessage = AppModel.message(for: error)
        }
    }

    func setMode(_ mode: GeoFilterMode, service: RouterServicing) async {
        let previous = settings.mode
        settings.mode = mode
        await write(revert: { self.settings.mode = previous }) {
            try await service.setGeoFilterMode(mode)
        }
    }

    func setStrictMode(_ enabled: Bool, service: RouterServicing) async {
        let previous = settings.strictMode
        settings.strictMode = enabled
        await write(revert: { self.settings.strictMode = previous }) {
            try await service.setGeoFilterStrictMode(enabled)
        }
    }

    /// Called continuously while the radius slider moves.
    func radiusChanged(to kilometers: Double, service: RouterServicing) {
        settings.radiusKilometers = kilometers
        pendingRadiusTask?.cancel()
        pendingRadiusTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.writeDebounce)
            guard !Task.isCancelled else { return }
            await self.write(revert: nil) {
                try await service.setGeoFilterRadius(kilometers: kilometers)
            }
        }
    }

    func pingAssistChanged(to milliseconds: Double, service: RouterServicing) {
        settings.pingAssistMilliseconds = milliseconds
        pendingPingAssistTask?.cancel()
        pendingPingAssistTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.writeDebounce)
            guard !Task.isCancelled else { return }
            await self.write(revert: nil) {
                try await service.setPingAssist(milliseconds: milliseconds)
            }
        }
    }

    func setHome(latitude: Double, longitude: Double, service: RouterServicing) async {
        let previous = (settings.homeLatitude, settings.homeLongitude)
        settings.homeLatitude = latitude
        settings.homeLongitude = longitude
        await write(revert: {
            self.settings.homeLatitude = previous.0
            self.settings.homeLongitude = previous.1
        }) {
            try await service.setGeoFilterHome(latitude: latitude, longitude: longitude)
        }
    }

    /// Peers sorted nearest-first, which is the order that matters when you're
    /// deciding whether the radius is too tight.
    var sortedPeers: [GeoPeer] {
        peers.sorted { lhs, rhs in
            lhs.distanceKilometers(from: settings.homeCoordinate)
                < rhs.distanceKilometers(from: settings.homeCoordinate)
        }
    }

    var peersInsideRadius: Int {
        peers.filter { $0.distanceKilometers(from: settings.homeCoordinate) <= settings.radiusKilometers }.count
    }

    /// Applies a write, rolling the optimistic UI change back if it fails.
    private func write(revert: (() -> Void)?, _ work: () async throws -> Void) async {
        do {
            try await work()
            errorMessage = nil
        } catch {
            revert?()
            errorMessage = AppModel.message(for: error)
        }
    }
}
