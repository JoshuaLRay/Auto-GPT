import SwiftUI

/// A small console for calling DumaOS procedures directly.
///
/// DumaOS is undocumented and procedure signatures drift between firmware
/// revisions, so this screen exists to answer "what does *my* XR500 actually
/// return?" without a laptop and a proxy.
struct RPCExplorerView: View {
    @EnvironmentObject private var model: AppModel

    @State private var package = DumaPackage.systemInfo
    @State private var method = "get_system_info"
    @State private var paramsText = "[]"
    @State private var output = ""
    @State private var isRunning = false

    var body: some View {
        Form {
            Section("Package") {
                Picker("Package", selection: $package) {
                    ForEach(Self.packages, id: \.self) { identifier in
                        Text(identifier.replacingOccurrences(of: "com.netdumasoftware.", with: ""))
                            .tag(identifier)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Procedure") {
                TextField("get_system_info", text: $method)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Menu("Common procedures") {
                    ForEach(Self.suggestions(for: package), id: \.self) { suggestion in
                        Button(suggestion) { method = suggestion }
                    }
                }
            }

            Section {
                TextField("[]", text: $paramsText, axis: .vertical)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .lineLimit(2...6)
            } header: {
                Text("Parameters")
            } footer: {
                Text("A JSON array. Most read-only procedures take []. Many procedures double as setters: calling one with a single argument writes that value.")
            }

            Section {
                Button {
                    run()
                } label: {
                    HStack {
                        Text("Call").fontWeight(.semibold)
                        if isRunning {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRunning || method.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !output.isEmpty {
                Section("Response") {
                    Text(output)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("RPC explorer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func run() {
        isRunning = true
        output = ""

        let params: [JSONValue]
        do {
            params = try Self.parseParameters(paramsText)
        } catch {
            output = "Parameters must be a JSON array, e.g. [] or [true] or [\"aa:bb:cc\"]."
            isRunning = false
            return
        }

        Task {
            do {
                let result = try await model.service.rawRPC(
                    package: package,
                    method: method.trimmingCharacters(in: .whitespaces),
                    params: params
                )
                output = JSONValue.array(result).prettyPrinted
            } catch {
                output = AppModel.message(for: error)
            }
            isRunning = false
        }
    }

    static func parseParameters(_ text: String) throws -> [JSONValue] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let data = Data(trimmed.utf8)
        return try JSONDecoder().decode([JSONValue].self, from: data)
    }

    private static let packages = [
        DumaPackage.systemInfo,
        DumaPackage.deviceManager,
        DumaPackage.geoFilter,
        DumaPackage.qos,
        DumaPackage.trafficController,
        DumaPackage.networkMonitor,
        DumaPackage.adBlocker,
        DumaPackage.benchmark,
        DumaPackage.pingHeatmap
    ]

    /// Procedure names registered by each R-App on XR-series firmware.
    static func suggestions(for package: String) -> [String] {
        switch package {
        case DumaPackage.systemInfo:
            return ["get_system_info", "get_cpu_info", "get_ram_info", "get_flash_info",
                    "get_network_statistics", "get_wan_ip", "read_log", "reboot"]
        case DumaPackage.deviceManager:
            return ["get_all_devices", "get_device", "get_device_ips", "get_types",
                    "get_online_interfaces", "get_network_view", "get_extenders",
                    "set_device_name", "set_device_type", "block_device", "delete_all_offline"]
        case DumaPackage.geoFilter:
            return ["get_all", "get_all_hosts", "mode", "strict", "distance", "pingass",
                    "home", "get_polygons", "geoservice_reverse_lookup", "upsert_host", "remove_host"]
        case DumaPackage.qos:
            return ["get_bandwidth", "set_bandwidth", "get_link_throttle", "set_link_throttle",
                    "get_bandwidth_dist_tree", "set_bandwidth_dist_tree", "get_acceleration",
                    "set_acceleration", "get_hyperlane_services", "get_categories", "stats"]
        case DumaPackage.trafficController:
            return ["get_rules", "get_rule", "add_rule", "update_rule", "delete_rule",
                    "reorder_rule", "get_log", "disable_rules"]
        case DumaPackage.networkMonitor:
            return ["filter_connections"]
        default:
            return []
        }
    }
}

#Preview {
    NavigationStack {
        RPCExplorerView()
    }
    .environmentObject(AppModel.preview)
}
