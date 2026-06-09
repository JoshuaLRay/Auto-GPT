import SwiftUI

/// Edit team names and reset the game.
struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Game format") {
                    Picker("Balls in play", selection: Binding(
                        get: { store.game.format },
                        set: { store.setFormat($0) }
                    )) {
                        ForEach(GameFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Six-ball adds Green and Orange. Switching keeps the balls you already have; it doesn't reset the game.")
                }

                Section("Team names") {
                    ForEach(Team.allCases) { team in
                        HStack {
                            ForEach(store.game.balls(for: team)) { BallChip(ball: $0, size: 22) }
                            TextField(store.game.defaultName(for: team), text: Binding(
                                get: { store.game.teamNames[team] ?? "" },
                                set: { store.setTeamName($0, for: team) }
                            ))
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset game", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Clears all deadness, resets every ball to wicket 1, and keeps no history.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset the game?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    store.resetGame()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}
