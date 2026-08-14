import SwiftUI

@main
struct XRControlApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(Theme.accent)
        }
    }
}

/// Switches between the sign-in screen and the tab bar.
struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.state.isConnected {
                MainTabView()
                    .transition(.opacity)
            } else {
                ConnectView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.state.isConnected)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.33percent") }

            GeoFilterView()
                .tabItem { Label("Geo-Filter", systemImage: "globe.americas.fill") }

            CongestionControlView()
                .tabItem { Label("Bandwidth", systemImage: "chart.pie.fill") }

            DeviceListView()
                .tabItem { Label("Devices", systemImage: "rectangle.stack.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppModel.preview)
}
