import Foundation
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot?
    @Published private(set) var samples: [ThroughputSample] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    /// Set when the router rejects the session, so the view can hand control
    /// back to the sign-in screen instead of looping on a dead connection.
    @Published private(set) var requiresReauthentication = false

    /// How often the dashboard re-polls while it is on screen.
    private let pollInterval: Duration = .seconds(5)
    /// Roughly two minutes of history at the poll interval above.
    private let maximumSamples = 24

    private var pollTask: Task<Void, Never>?
    private var previousStatistics: (stats: NetworkStatistics, date: Date)?

    func start(service: RouterServicing) {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(service: service)
                guard let interval = self?.pollInterval else { return }
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh(service: RouterServicing) async {
        if snapshot == nil { isLoading = true }
        defer { isLoading = false }

        do {
            let next = try await service.fetchDashboard()
            appendSample(from: next)
            snapshot = next
            errorMessage = nil
        } catch {
            errorMessage = AppModel.message(for: error)
            if (error as? RouterError)?.isAuthenticationFailure == true {
                requiresReauthentication = true
            }
        }
    }

    /// Derives an instantaneous throughput reading by differencing the WAN byte
    /// counters against the previous poll.
    private func appendSample(from next: DashboardSnapshot) {
        defer { previousStatistics = (next.network, next.capturedAt) }
        guard let previous = previousStatistics else { return }
        guard let sample = ThroughputSample.between(
            previous: previous.stats,
            previousDate: previous.date,
            current: next.network,
            currentDate: next.capturedAt
        ) else { return }

        samples.append(sample)
        if samples.count > maximumSamples {
            samples.removeFirst(samples.count - maximumSamples)
        }
    }

    var currentDownstream: Double { samples.last?.downstream ?? 0 }
    var currentUpstream: Double { samples.last?.upstream ?? 0 }
}
