import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    @State private var isRebooting = false
    @State private var showsRebootConfirmation = false
    @State private var rebootMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Router") {
                    LabeledContent("Model", value: model.state.systemInfo?.model ?? "—")
                    LabeledContent("Board", value: model.state.systemInfo?.boardName ?? "—")
                    LabeledContent("Platform", value: model.state.systemInfo?.platform ?? "—")
                    LabeledContent("Firmware", value: model.state.systemInfo?.firmwareVersion ?? "—")
                    LabeledContent("DumaOS", value: model.state.systemInfo?.dumaOSVersion ?? "—")
                    LabeledContent("Uptime", value: Format.uptime(model.state.systemInfo?.uptime ?? 0))
                }

                Section("Connection") {
                    LabeledContent("Address", value: model.credentials.trimmedHost)
                    LabeledContent("Username", value: model.credentials.username)
                    LabeledContent("Mode", value: model.isDemoMode ? "Demo data" : "Live router")
                }

                Section {
                    NavigationLink {
                        RPCExplorerView()
                    } label: {
                        Label("RPC explorer", systemImage: "terminal")
                    }
                } footer: {
                    Text("Call any DumaOS procedure directly and read the raw response. Useful for confirming what your firmware supports.")
                }

                Section {
                    Button {
                        showsRebootConfirmation = true
                    } label: {
                        HStack {
                            Label("Reboot router", systemImage: "arrow.clockwise")
                            if isRebooting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRebooting)

                    if let rebootMessage {
                        Text(rebootMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Everyone on the network loses their connection for a couple of minutes.")
                }

                Section {
                    Button("Sign out") {
                        model.disconnect()
                    }
                    Button("Forget saved password", role: .destructive) {
                        model.forgetSavedCredentials()
                    }
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About this app", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reboot the router?",
                isPresented: $showsRebootConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reboot", role: .destructive) { reboot() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The network goes down until the router finishes restarting.")
            }
        }
    }

    private func reboot() {
        isRebooting = true
        rebootMessage = nil
        Task {
            do {
                try await model.service.reboot()
                rebootMessage = "Reboot command sent. The router will be back in a minute or two."
            } catch {
                rebootMessage = AppModel.message(for: error)
            }
            isRebooting = false
        }
    }
}

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                Text("XR Control is an unofficial client for routers running DumaOS, built and tested against the NETGEAR Nighthawk XR500.")
                Text("It is not affiliated with, endorsed by, or supported by NETGEAR or Netduma.")
                    .foregroundStyle(.secondary)
            }

            Section("How it talks to the router") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DumaOS RPC").font(.subheadline.weight(.semibold))
                    Text("JSON-RPC 2.0 over HTTP to /apps/<package>/rpc/ — the same endpoints the router's own web interface uses for Geo-Filter, Congestion Control and Device Manager.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("NETGEAR SOAP").font(.subheadline.weight(.semibold))
                    Text("The firmware's SOAP service on port 5000, used for Wi-Fi link details and as a reboot fallback.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Everything happens on your local network. The app has no backend, sends no analytics, and stores your password only in the iOS keychain.")
                    .font(.footnote)
            } header: {
                Text("Privacy")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppModel.preview)
}
