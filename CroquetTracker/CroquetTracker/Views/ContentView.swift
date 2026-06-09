import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: GameStore
    @State private var showSettings = false

    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DeadnessBoardView()

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.game.balls) { ball in
                            BallTrackerView(ball: ball)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Croquet")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameStore(defaults: UserDefaults(suiteName: "preview")!))
}
