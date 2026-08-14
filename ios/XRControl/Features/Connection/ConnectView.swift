import SwiftUI

/// Sign-in screen. Collects the same credentials you use for the router's web
/// interface and verifies them with a single `get_system_info` call.
struct ConnectView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsAdvanced = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case host, username, password
    }

    private var isBusy: Bool { model.state == .connecting }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section("Router") {
                    LabeledContent("Address") {
                        TextField("192.168.1.1", text: $model.credentials.host)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .host)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .username }
                    }

                    LabeledContent("Username") {
                        TextField("admin", text: $model.credentials.username)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }

                    LabeledContent("Password") {
                        SecureField("Required", text: $model.credentials.password)
                            .textContentType(.password)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { connect() }
                    }
                } footer: {
                    Text("Use the admin account you sign in to the DumaOS web interface with.")
                }

                Section {
                    Toggle("Save credentials", isOn: $model.rememberCredentials)
                } footer: {
                    Text("The password is stored in the iOS keychain and never leaves your device.")
                }

                advancedSection

                Section {
                    Button(action: connect) {
                        HStack {
                            Spacer()
                            if isBusy {
                                ProgressView()
                            } else {
                                Text("Connect").fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isBusy || !model.credentials.isComplete)

                    Button("Explore in demo mode") {
                        Task { await model.startDemoMode() }
                    }
                    .disabled(isBusy)
                }

                if case .failed(let message) = model.state {
                    Section {
                        ErrorBanner(message: message)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                }
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.router.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("XR Control")
                .font(.title2.weight(.bold))
            Text("An unofficial controller for DumaOS routers, tuned for the Nighthawk XR500.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var advancedSection: some View {
        Section {
            DisclosureGroup("Ports and protocol", isExpanded: $showsAdvanced) {
                LabeledContent("Web port") {
                    TextField("80", value: $model.credentials.webPort, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("SOAP port") {
                    TextField("5000", value: $model.credentials.soapPort, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("Use HTTPS", isOn: $model.credentials.useHTTPS)
            }
        } header: {
            Text("Advanced")
        }
    }

    private func connect() {
        focusedField = nil
        Task { await model.connect() }
    }
}

#Preview {
    ConnectView()
        .environmentObject(AppModel())
}
