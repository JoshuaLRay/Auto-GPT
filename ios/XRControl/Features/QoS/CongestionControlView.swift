import Charts
import SwiftUI

/// Congestion Control: the WAN speeds DumaOS shapes against, Anti-Bufferbloat,
/// and each device's slice of the pie.
struct CongestionControlView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var viewModel = CongestionControlViewModel()

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: errorMessage) {
                            Task { await viewModel.load(service: model.service) }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                }

                if let statusMessage = viewModel.statusMessage {
                    Section {
                        Label(statusMessage, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.accent)
                    }
                }

                bandwidthSection
                antiBufferbloatSection
                allocationSection
                prioritySection
                accelerationSection
            }
            .navigationTitle("Bandwidth")
            .refreshable { await viewModel.load(service: model.service) }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Reading QoS settings…")
                }
            }
        }
        .task { await viewModel.load(service: model.service) }
    }

    // MARK: - Sections

    private var bandwidthSection: some View {
        Section {
            speedRow(title: "Download", value: $viewModel.downloadMbps, tint: Theme.downstream)
            speedRow(title: "Upload", value: $viewModel.uploadMbps, tint: Theme.upstream)

            if viewModel.hasUnsavedBandwidthChanges {
                Button("Save speeds") {
                    Task { await viewModel.saveBandwidth(service: model.service) }
                }
                .disabled(viewModel.isSaving)
            }
        } header: {
            Text("Your connection speed")
        } footer: {
            Text("Set these to roughly 80–90% of a real speed test result. DumaOS shapes traffic against these numbers, so guessing high defeats Anti-Bufferbloat.")
        }
    }

    private func speedRow(title: String, value: Binding<Double>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                    .monospacedDigit()
                Text("Mbps").foregroundStyle(.secondary)
            }
            Slider(value: value, in: 1...1000, step: 1)
                .tint(tint)
        }
    }

    private var antiBufferbloatSection: some View {
        Section {
            Toggle("Anti-Bufferbloat", isOn: Binding(
                get: { viewModel.snapshot.throttle.isEnabled },
                set: { enabled in
                    Task { await viewModel.setThrottleEnabled(enabled, service: model.service) }
                }
            ))

            if viewModel.snapshot.throttle.isEnabled {
                throttleRow(
                    title: "Download limit",
                    fraction: viewModel.snapshot.throttle.downstreamFraction,
                    absolute: viewModel.downloadMbps,
                    tint: Theme.downstream
                ) { value in
                    Task { await viewModel.setThrottleFraction(downstream: value, upstream: nil, service: model.service) }
                }

                throttleRow(
                    title: "Upload limit",
                    fraction: viewModel.snapshot.throttle.upstreamFraction,
                    absolute: viewModel.uploadMbps,
                    tint: Theme.upstream
                ) { value in
                    Task { await viewModel.setThrottleFraction(downstream: nil, upstream: value, service: model.service) }
                }
            }
        } header: {
            Text("Anti-Bufferbloat")
        } footer: {
            Text("Holds the link below its saturation point so a big download can't add latency to a game. 70% is a good starting point.")
        }
    }

    private func throttleRow(
        title: String,
        fraction: Double,
        absolute: Double,
        tint: Color,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(Format.percent(fraction)) · \(Format.megabits(absolute * fraction))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(get: { fraction }, set: onChange),
                in: 0.1...1.0,
                step: 0.05
            )
            .tint(tint)
        }
    }

    @ViewBuilder
    private var allocationSection: some View {
        Section {
            if viewModel.allocations.isEmpty {
                Text("No per-device allocation is configured on this router.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                allocationChart
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))

                ForEach($viewModel.allocations) { $allocation in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(allocation.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(Format.percent(allocation.downstreamShare))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $allocation.downstreamShare, in: 0.01...1.0, step: 0.01)
                    }
                }

                HStack {
                    Button("Even split") { viewModel.distributeEvenly() }
                    Spacer()
                    if viewModel.hasUnsavedAllocationChanges {
                        Button("Discard") { viewModel.resetAllocations() }
                            .foregroundStyle(Theme.danger)
                        Button("Save") {
                            Task { await viewModel.saveAllocations(service: model.service) }
                        }
                        .fontWeight(.semibold)
                        .disabled(viewModel.isSaving)
                    }
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("Device allocation")
        } footer: {
            Text("Shares are normalised to 100% when saved. A device only uses its share when the link is congested.")
        }
    }

    private var allocationChart: some View {
        Chart(viewModel.allocations) { allocation in
            SectorMark(
                angle: .value("Share", max(0.01, allocation.downstreamShare)),
                innerRadius: .ratio(0.58),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(by: .value("Device", allocation.name))
        }
        .chartLegend(position: .trailing, alignment: .center, spacing: 8)
    }

    @ViewBuilder
    private var prioritySection: some View {
        if !viewModel.snapshot.services.isEmpty {
            Section("Traffic prioritisation") {
                ForEach(viewModel.snapshot.services) { service in
                    HStack {
                        Image(systemName: service.isEnabled ? "bolt.fill" : "bolt.slash")
                            .foregroundStyle(service.isEnabled ? Theme.accent : .secondary)
                        Text(service.name)
                        Spacer()
                        Text(service.isEnabled ? "Prioritised" : "Off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var accelerationSection: some View {
        Section {
            Toggle("Hardware acceleration", isOn: Binding(
                get: { viewModel.snapshot.hardwareAccelerationEnabled },
                set: { enabled in
                    Task { await viewModel.setHardwareAcceleration(enabled, service: model.service) }
                }
            ))
        } footer: {
            Text("Raises maximum throughput but bypasses QoS for accelerated flows. Leave it off if you rely on Anti-Bufferbloat.")
        }
    }
}

#Preview {
    CongestionControlView()
        .environmentObject(AppModel.preview)
}
