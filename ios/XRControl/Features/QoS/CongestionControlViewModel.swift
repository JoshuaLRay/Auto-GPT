import Foundation
import SwiftUI

@MainActor
final class CongestionControlViewModel: ObservableObject {
    @Published private(set) var snapshot = QoSSnapshot()
    @Published var allocations: [BandwidthAllocation] = []
    @Published var downloadMbps: Double = 0
    @Published var uploadMbps: Double = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private var hasLoaded = false

    func load(service: RouterServicing) async {
        isLoading = !hasLoaded
        statusMessage = nil
        defer { isLoading = false }
        do {
            let next = try await service.fetchQoS()
            snapshot = next
            allocations = next.allocations
            downloadMbps = next.bandwidth.downloadMbps
            uploadMbps = next.bandwidth.uploadMbps
            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = AppModel.message(for: error)
        }
    }

    // MARK: - Bandwidth

    var hasUnsavedBandwidthChanges: Bool {
        abs(downloadMbps - snapshot.bandwidth.downloadMbps) > 0.05
            || abs(uploadMbps - snapshot.bandwidth.uploadMbps) > 0.05
    }

    func saveBandwidth(service: RouterServicing) async {
        let settings = BandwidthSettings(downloadMbps: downloadMbps, uploadMbps: uploadMbps)
        await perform("Bandwidth limits saved.") {
            try await service.setBandwidth(settings)
            self.snapshot.bandwidth = settings
        }
    }

    // MARK: - Anti-Bufferbloat

    func setThrottleEnabled(_ enabled: Bool, service: RouterServicing) async {
        var throttle = snapshot.throttle
        throttle.isEnabled = enabled
        await applyThrottle(throttle, service: service)
    }

    func setThrottleFraction(downstream: Double?, upstream: Double?, service: RouterServicing) async {
        var throttle = snapshot.throttle
        if let downstream { throttle.downstreamFraction = downstream }
        if let upstream { throttle.upstreamFraction = upstream }
        await applyThrottle(throttle, service: service)
    }

    private func applyThrottle(_ throttle: ThrottleSettings, service: RouterServicing) async {
        let previous = snapshot.throttle
        snapshot.throttle = throttle
        await perform(nil) {
            do {
                try await service.setThrottle(throttle)
            } catch {
                self.snapshot.throttle = previous
                throw error
            }
        }
    }

    func setHardwareAcceleration(_ enabled: Bool, service: RouterServicing) async {
        let previous = snapshot.hardwareAccelerationEnabled
        snapshot.hardwareAccelerationEnabled = enabled
        await perform(nil) {
            do {
                try await service.setHardwareAcceleration(enabled)
            } catch {
                self.snapshot.hardwareAccelerationEnabled = previous
                throw error
            }
        }
    }

    // MARK: - Allocations

    /// Rebalances so shares always sum to 1 — the router rejects a tree whose
    /// proportions do not normalise.
    func normalizeAllocations() {
        let downTotal = allocations.reduce(0) { $0 + $1.downstreamShare }
        let upTotal = allocations.reduce(0) { $0 + $1.upstreamShare }
        guard downTotal > 0, upTotal > 0 else { return }
        for index in allocations.indices {
            allocations[index].downstreamShare /= downTotal
            allocations[index].upstreamShare /= upTotal
        }
    }

    var hasUnsavedAllocationChanges: Bool {
        allocations != snapshot.allocations
    }

    func saveAllocations(service: RouterServicing) async {
        normalizeAllocations()
        let payload = allocations
        await perform("Bandwidth allocation saved.") {
            try await service.setAllocations(payload)
            self.snapshot.allocations = payload
        }
    }

    func resetAllocations() {
        allocations = snapshot.allocations
    }

    /// Splits bandwidth evenly across every device.
    func distributeEvenly() {
        guard !allocations.isEmpty else { return }
        let share = 1.0 / Double(allocations.count)
        for index in allocations.indices {
            allocations[index].downstreamShare = share
            allocations[index].upstreamShare = share
        }
    }

    // MARK: - Helpers

    private func perform(_ successMessage: String?, _ work: () async throws -> Void) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await work()
            errorMessage = nil
            statusMessage = successMessage
        } catch {
            errorMessage = AppModel.message(for: error)
            statusMessage = nil
        }
    }
}
