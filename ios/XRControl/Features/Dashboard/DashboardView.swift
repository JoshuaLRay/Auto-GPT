import Charts
import SwiftUI

/// Live overview: WAN throughput, router load, and how many devices are online.
struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var viewModel = DashboardViewModel()

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            Task { await viewModel.refresh(service: model.service) }
                        }
                    }

                    if model.isDemoMode {
                        demoNotice
                    }

                    throughputCard

                    LazyVGrid(columns: columns, spacing: 12) {
                        StatTile(
                            title: "Devices online",
                            value: "\(viewModel.snapshot?.onlineDeviceCount ?? 0)",
                            caption: "on the LAN right now",
                            systemImage: "rectangle.stack.fill"
                        )
                        StatTile(
                            title: "CPU",
                            value: Format.percent(viewModel.snapshot?.cpu.averageUsage ?? 0),
                            caption: coreCaption,
                            systemImage: "cpu.fill",
                            tint: Theme.upstream
                        )
                        StatTile(
                            title: "Uptime",
                            value: Format.uptime(viewModel.snapshot?.systemInfo.uptime ?? 0),
                            caption: "since last reboot",
                            systemImage: "clock.fill",
                            tint: Theme.downstream
                        )
                        StatTile(
                            title: "WAN IP",
                            value: viewModel.snapshot?.network.wanIPAddress ?? "—",
                            caption: "public address",
                            systemImage: "network",
                            tint: Theme.warning
                        )
                    }

                    memoryCard
                    totalsCard
                    routerCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .refreshable { await viewModel.refresh(service: model.service) }
            .overlay {
                if viewModel.isLoading && viewModel.snapshot == nil {
                    ProgressView("Reading router status…")
                }
            }
        }
        .task { viewModel.start(service: model.service) }
        .onDisappear { viewModel.stop() }
        .onChange(of: viewModel.requiresReauthentication) { _, needsSignIn in
            guard needsSignIn else { return }
            viewModel.stop()
            model.handleAuthenticationFailure()
        }
    }

    // MARK: - Sections

    private var demoNotice: some View {
        Label("Demo mode — showing sample data, not your router.", systemImage: "theatermasks.fill")
            .font(.footnote.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.upstream.opacity(0.14))
            )
    }

    private var throughputCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.downstream)
                        Text(Format.bitsPerSecond(viewModel.currentDownstream))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Upload")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.upstream)
                        Text(Format.bitsPerSecond(viewModel.currentUpstream))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                }

                if viewModel.samples.count < 2 {
                    Text("Collecting samples…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    throughputChart
                        .frame(height: 140)
                }
            }
        }
    }

    private var throughputChart: some View {
        Chart {
            ForEach(viewModel.samples) { sample in
                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Bits per second", sample.downstream),
                    series: .value("Direction", "Download")
                )
                .foregroundStyle(Theme.downstream.opacity(0.25))

                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Bits per second", sample.downstream),
                    series: .value("Direction", "Download")
                )
                .foregroundStyle(Theme.downstream)
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Bits per second", sample.upstream),
                    series: .value("Direction", "Upload")
                )
                .foregroundStyle(Theme.upstream)
                .interpolationMethod(.monotone)
            }
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let rate = value.as(Double.self) {
                        Text(Format.bitsPerSecond(rate)).font(.caption2)
                    }
                }
            }
        }
    }

    private var memoryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Router resources")
                    .font(.headline)

                usageRow(
                    title: "Memory",
                    info: viewModel.snapshot?.memory ?? StorageInfo(),
                    tint: Theme.accent
                )
                usageRow(
                    title: "Flash",
                    info: viewModel.snapshot?.flash ?? StorageInfo(),
                    tint: Theme.warning
                )

                if let load = viewModel.snapshot?.systemInfo.loadAverage, !load.isEmpty {
                    LabeledContent("Load average") {
                        Text(load.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: "  "))
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func usageRow(title: String, info: StorageInfo, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(info.totalBytes > 0
                     ? "\(Format.bytes(info.usedBytes)) of \(Format.bytes(info.totalBytes))"
                     : "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            UsageBar(fraction: info.usedFraction, tint: tint)
        }
    }

    private var totalsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Since last reboot")
                    .font(.headline)
                LabeledContent("Downloaded", value: Format.bytes(viewModel.snapshot?.network.receivedBytes ?? 0))
                LabeledContent("Uploaded", value: Format.bytes(viewModel.snapshot?.network.transmittedBytes ?? 0))
                LabeledContent("Dropped packets", value: droppedDescription)
            }
            .font(.subheadline)
        }
    }

    private var routerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Router")
                    .font(.headline)
                LabeledContent("Model", value: viewModel.snapshot?.systemInfo.model ?? "—")
                LabeledContent("Firmware", value: viewModel.snapshot?.systemInfo.firmwareVersion ?? "—")
                LabeledContent("DumaOS", value: viewModel.snapshot?.systemInfo.dumaOSVersion ?? "—")
            }
            .font(.subheadline)
        }
    }

    // MARK: - Derived text

    private var coreCaption: String {
        let cores = viewModel.snapshot?.cpu.coreUsage.count ?? 0
        return cores > 0 ? "\(cores) core\(cores == 1 ? "" : "s")" : "utilisation"
    }

    private var droppedDescription: String {
        let network = viewModel.snapshot?.network
        let received = Int(network?.receivedDropped ?? 0)
        let transmitted = Int(network?.transmittedDropped ?? 0)
        return "\(received) in · \(transmitted) out"
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppModel.preview)
}
