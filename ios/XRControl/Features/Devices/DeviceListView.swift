import SwiftUI

/// Every device the router knows about, with the ones that are online first.
struct DeviceListView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var viewModel = DevicesViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: errorMessage) {
                            Task { await viewModel.load(service: model.service) }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                }

                if viewModel.devices.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        title: "No devices",
                        message: "The router hasn't reported any devices yet.",
                        systemImage: "rectangle.stack"
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(viewModel.filteredDevices) { device in
                            NavigationLink {
                                DeviceDetailView(deviceID: device.id, viewModel: viewModel)
                            } label: {
                                DeviceRow(device: device)
                            }
                        }
                    } header: {
                        Text("\(viewModel.onlineCount) online · \(viewModel.devices.count) known")
                    }
                }
            }
            .navigationTitle("Devices")
            .searchable(text: $viewModel.searchText, prompt: "Name, IP, or MAC")
            .refreshable { await viewModel.load(service: model.service) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        TrafficControlView()
                    } label: {
                        Image(systemName: "shield.lefthalf.filled")
                    }
                    .accessibilityLabel("Traffic Controller")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Show offline devices", isOn: $viewModel.showsOfflineDevices)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Reading device list…")
                }
            }
        }
        .task { await viewModel.load(service: model.service) }
    }
}

private struct DeviceRow: View {
    let device: NetworkDevice

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(device.isOnline ? Theme.accent.opacity(0.16) : Color(.tertiarySystemFill))
                    .frame(width: 38, height: 38)
                Image(systemName: device.symbolName)
                    .foregroundStyle(device.isOnline ? Theme.accent : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.body)
                        .lineLimit(1)
                    if device.isBlocked {
                        Image(systemName: "hand.raised.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.danger)
                    }
                }
                Text(device.ipAddress ?? device.macAddress ?? "—")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(device.connectionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let signal = device.signalStrength {
                    Label("\(Int(signal))%", systemImage: signalSymbol(for: signal))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .opacity(device.isOnline ? 1 : 0.55)
    }

    private func signalSymbol(for strength: Double) -> String {
        strength < 40 ? "wifi.exclamationmark" : "wifi"
    }
}

/// Detail and per-device actions.
struct DeviceDetailView: View {
    let deviceID: String
    @ObservedObject var viewModel: DevicesViewModel
    @EnvironmentObject private var model: AppModel

    @State private var draftName = ""
    @State private var isEditingName = false
    @State private var showsRawPayload = false

    private var device: NetworkDevice? { viewModel.device(withID: deviceID) }

    var body: some View {
        Form {
            if let device {
                Section("Identity") {
                    if isEditingName {
                        HStack {
                            TextField("Device name", text: $draftName)
                                .textInputAutocapitalization(.words)
                            Button("Save") {
                                Task {
                                    await viewModel.rename(device, to: draftName, service: model.service)
                                    isEditingName = false
                                }
                            }
                            .buttonStyle(.borderless)
                            .fontWeight(.semibold)
                        }
                    } else {
                        LabeledContent("Name", value: device.name)
                        Button("Rename") {
                            draftName = device.name
                            isEditingName = true
                        }
                    }
                    LabeledContent("Type", value: device.deviceType.replacingOccurrences(of: "_", with: " ").capitalized)
                }

                Section("Connection") {
                    LabeledContent("Status", value: device.isOnline ? "Online" : "Offline")
                    if let ip = device.ipAddress { LabeledContent("IP address", value: ip) }
                    if let mac = device.macAddress { LabeledContent("MAC address", value: mac) }
                    if let ssid = device.ssid { LabeledContent("Network", value: ssid) }
                    if let speed = device.linkSpeed {
                        LabeledContent("Link rate", value: "\(Int(speed)) Mbps")
                    }
                    if let signal = device.signalStrength {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Signal")
                                Spacer()
                                Text("\(Int(signal))%").foregroundStyle(.secondary).monospacedDigit()
                            }
                            UsageBar(fraction: signal / 100, tint: signal < 40 ? Theme.warning : Theme.accent)
                        }
                    }
                }

                Section {
                    Toggle("Block internet access", isOn: Binding(
                        get: { device.isBlocked },
                        set: { blocked in
                            Task { await viewModel.setBlocked(blocked, device: device, service: model.service) }
                        }
                    ))
                } footer: {
                    Text("Blocking cuts this device off from the internet but leaves it on the local network.")
                }

                if let raw = device.raw {
                    Section {
                        DisclosureGroup("Raw router payload", isExpanded: $showsRawPayload) {
                            Text(raw.prettyPrinted)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    } footer: {
                        Text("Everything the router reported for this device, useful when a field above shows a dash.")
                    }
                }
            } else {
                EmptyStateView(
                    title: "Device unavailable",
                    message: "This device is no longer in the router's list.",
                    systemImage: "questionmark.circle"
                )
            }
        }
        .navigationTitle(device?.name ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    DeviceListView()
        .environmentObject(AppModel.preview)
}
