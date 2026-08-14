import MapKit
import SwiftUI

/// The Geo-Filter: a map of every host the router has seen, a radius you can
/// drag, and the switches that decide whether that radius is enforced.
struct GeoFilterView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var viewModel = GeoFilterViewModel()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPeer: GeoPeer?
    @State private var showsControls = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                map
                    .overlay(alignment: .top) {
                        if let errorMessage = viewModel.errorMessage {
                            ErrorBanner(message: errorMessage) {
                                Task { await viewModel.load(service: model.service) }
                            }
                            .padding(12)
                        }
                    }

                if showsControls {
                    controls
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Geo-Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showsControls.toggle() }
                    } label: {
                        Image(systemName: showsControls ? "chevron.down.circle" : "slider.horizontal.3")
                    }
                    .accessibilityLabel(showsControls ? "Hide controls" : "Show controls")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        recenter()
                    } label: {
                        Image(systemName: "scope")
                    }
                    .accessibilityLabel("Centre on home")
                }
            }
            .sheet(item: $selectedPeer) { peer in
                PeerDetailSheet(peer: peer, home: viewModel.settings.homeCoordinate)
                    .presentationDetents([.height(280)])
            }
        }
        .task {
            await viewModel.load(service: model.service)
            recenter()
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $cameraPosition) {
            MapCircle(center: viewModel.settings.homeCoordinate, radius: viewModel.settings.radiusMeters)
                .foregroundStyle(Theme.accent.opacity(0.14))
                .stroke(Theme.accent, lineWidth: 2)

            Annotation("Home", coordinate: viewModel.settings.homeCoordinate) {
                Image(systemName: "house.fill")
                    .font(.caption)
                    .padding(7)
                    .background(Circle().fill(Theme.accent))
                    .foregroundStyle(.white)
            }

            ForEach(viewModel.peers) { peer in
                Annotation(peer.ipAddress, coordinate: peer.coordinate) {
                    Button {
                        selectedPeer = peer
                    } label: {
                        Image(systemName: peer.kind == .server ? "server.rack" : "person.fill")
                            .font(.caption2)
                            .padding(6)
                            .background(Circle().fill(tint(for: peer)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .overlay(alignment: .bottomLeading) { legend }
    }

    private func tint(for peer: GeoPeer) -> Color {
        if peer.isDenied { return Theme.danger }
        if peer.isAllowed { return Theme.accent }
        let inside = peer.distanceKilometers(from: viewModel.settings.homeCoordinate)
            <= viewModel.settings.radiusKilometers
        return inside ? Theme.downstream : .gray
    }

    private var legend: some View {
        HStack(spacing: 10) {
            legendDot(color: Theme.accent, label: "Allowed")
            legendDot(color: Theme.downstream, label: "In range")
            legendDot(color: .gray, label: "Out of range")
            legendDot(color: Theme.danger, label: "Denied")
        }
        .font(.caption2)
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(10)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
    }

    private func recenter() {
        let radius = max(viewModel.settings.radiusMeters * 2.6, 200_000)
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: viewModel.settings.homeCoordinate,
                    latitudinalMeters: radius,
                    longitudinalMeters: radius
                )
            )
        }
    }

    // MARK: - Controls

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modePicker

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Radius").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(Format.distance(kilometers: viewModel.settings.radiusKilometers))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { viewModel.settings.radiusKilometers },
                            set: { viewModel.radiusChanged(to: $0, service: model.service) }
                        ),
                        in: 50...12_000,
                        step: 25
                    )
                    Text("\(viewModel.peersInsideRadius) of \(viewModel.peers.count) known hosts are inside the circle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Ping Assist").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(viewModel.settings.pingAssistMilliseconds == 0
                             ? "Off"
                             : Format.milliseconds(viewModel.settings.pingAssistMilliseconds))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { viewModel.settings.pingAssistMilliseconds },
                            set: { viewModel.pingAssistChanged(to: $0, service: model.service) }
                        ),
                        in: 0...200,
                        step: 5
                    )
                    Text("Allows servers outside the radius when they answer faster than this.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: Binding(
                    get: { viewModel.settings.strictMode },
                    set: { value in Task { await viewModel.setStrictMode(value, service: model.service) } }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strict mode").font(.subheadline.weight(.semibold))
                        Text("Blocks hosts the router can't place on the map.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    PeerListView(viewModel: viewModel)
                } label: {
                    Label("All hosts (\(viewModel.peers.count))", systemImage: "list.bullet")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 340)
        .background(Color(.systemGroupedBackground))
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Mode", selection: Binding(
                get: { viewModel.settings.mode },
                set: { mode in Task { await viewModel.setMode(mode, service: model.service) } }
            )) {
                ForEach(GeoFilterMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbolName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(viewModel.settings.mode.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Tapping a host on the map opens this.
private struct PeerDetailSheet: View {
    let peer: GeoPeer
    let home: CLLocationCoordinate2D

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("Address", value: peer.ipAddress)
                LabeledContent("Type", value: peer.kind == .server ? "Server" : "Peer")
                LabeledContent("Distance", value: Format.distance(kilometers: peer.distanceKilometers(from: home)))
                if let ping = peer.pingMilliseconds {
                    LabeledContent("Ping", value: Format.milliseconds(ping))
                }
                if let country = peer.countryName {
                    LabeledContent("Location", value: country)
                }
                LabeledContent("Status", value: statusText)
            }
            .navigationTitle(peer.ipAddress)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statusText: String {
        if peer.isDenied { return "Denied" }
        if peer.isAllowed { return "Allowed" }
        return "Filtered by radius"
    }
}

/// Every host the Geo-Filter knows about, nearest first.
private struct PeerListView: View {
    @ObservedObject var viewModel: GeoFilterViewModel

    var body: some View {
        List {
            if viewModel.peers.isEmpty {
                EmptyStateView(
                    title: "No hosts yet",
                    message: "Start a game session — hosts appear here as the router sees them.",
                    systemImage: "globe"
                )
                .listRowBackground(Color.clear)
            }

            ForEach(viewModel.sortedPeers) { peer in
                HStack(spacing: 12) {
                    Image(systemName: peer.kind == .server ? "server.rack" : "person.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(peer.ipAddress).font(.subheadline.weight(.medium))
                        Text(peer.countryName ?? "Unknown location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Format.distance(kilometers: peer.distanceKilometers(from: viewModel.settings.homeCoordinate)))
                            .font(.caption.monospacedDigit())
                        if let ping = peer.pingMilliseconds {
                            Text(Format.milliseconds(ping))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Hosts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    GeoFilterView()
        .environmentObject(AppModel.preview)
}
