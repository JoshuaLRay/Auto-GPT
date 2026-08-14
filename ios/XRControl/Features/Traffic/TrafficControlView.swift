import SwiftUI

@MainActor
final class TrafficControlViewModel: ObservableObject {
    @Published private(set) var rules: [TrafficRule] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load(service: RouterServicing) async {
        isLoading = rules.isEmpty
        defer { isLoading = false }
        do {
            rules = try await service.fetchTrafficRules()
            errorMessage = nil
        } catch {
            errorMessage = AppModel.message(for: error)
        }
    }

    func setEnabled(_ enabled: Bool, rule: TrafficRule, service: RouterServicing) async {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        let previous = rules[index].isEnabled
        rules[index].isEnabled = enabled
        do {
            try await service.setTrafficRuleEnabled(enabled, ruleID: rule.id)
            errorMessage = nil
        } catch {
            rules[index].isEnabled = previous
            errorMessage = AppModel.message(for: error)
        }
    }

    func delete(at offsets: IndexSet, service: RouterServicing) async {
        let doomed = offsets.map { rules[$0] }
        rules.remove(atOffsets: offsets)
        for rule in doomed {
            do {
                try await service.deleteTrafficRule(ruleID: rule.id)
            } catch {
                errorMessage = AppModel.message(for: error)
                await load(service: service)
                return
            }
        }
    }
}

/// Traffic Controller rules — allow, block, or reject traffic per device.
///
/// The app reads and toggles existing rules; composing a new rule needs the
/// service and category catalogues from the router, so it stays in the web UI.
struct TrafficControlView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var viewModel = TrafficControlViewModel()

    var body: some View {
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

            if viewModel.rules.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No rules",
                    message: "Traffic Controller rules you create in the DumaOS web interface show up here.",
                    systemImage: "shield"
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(viewModel.rules) { rule in
                        RuleRow(rule: rule) { enabled in
                            Task { await viewModel.setEnabled(enabled, rule: rule, service: model.service) }
                        }
                    }
                    .onDelete { offsets in
                        Task { await viewModel.delete(at: offsets, service: model.service) }
                    }
                } footer: {
                    Text("Rules run in order — the first match wins. Swipe to delete.")
                }
            }
        }
        .navigationTitle("Traffic Controller")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load(service: model.service) }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Reading rules…")
            }
        }
        .task { await viewModel.load(service: model.service) }
    }
}

private struct RuleRow: View {
    let rule: TrafficRule
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: rule.action.symbolName)
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.body)
                    .lineLimit(1)
                Text("\(rule.action.title) · \(rule.summary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: onToggle))
                .labelsHidden()
        }
    }

    private var tint: Color {
        switch rule.action {
        case .allow: return Theme.accent
        case .block: return Theme.warning
        case .reject: return Theme.danger
        }
    }
}

#Preview {
    NavigationStack {
        TrafficControlView()
    }
    .environmentObject(AppModel.preview)
}
