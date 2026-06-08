# Croquet Tracker

A small SwiftUI iOS app for scoring **American six-wicket croquet** at the
lawn. It tracks the three things you can't keep straight in your head mid-game:

- **Deadness board** — the classic grid showing which ball is dead on which.
  Tap any cell to toggle. A ball can't be dead on itself.
- **Next wicket per ball** — each ball shows the wicket it's running for
  (1 → 6 → 1-back … Rover → Stake), with a one-tap **Scored** button.
- **Player / team per ball** — Blue + Black vs Red + Yellow, with editable
  player names and team names.

Tapping **Scored** advances that ball to its next wicket *and* clears its
deadness automatically, matching the rules. The minus button steps a ball back
a wicket for corrections without touching deadness.

The in-progress game is saved to `UserDefaults` after every change, so it
survives backgrounding and restarts. There is a single live game; **Reset**
(in Settings) starts fresh.

## Running it

Requires **Xcode 16 or later** (the project uses file-system-synchronized
groups).

1. Open `CroquetTracker.xcodeproj` in Xcode.
2. Select an iPhone or iPad simulator (or your device).
3. Press **Run** (⌘R).

The bundle identifier is `com.example.CroquetTracker` — change it under the
target's Signing & Capabilities if you want to run on a physical device with
your own team.

## Project layout

```
CroquetTracker/
  CroquetTrackerApp.swift      App entry point
  Models/
    Ball.swift                 The four balls, colors, team membership
    Team.swift                 Blue/Black and Red/Yellow sides
    Wicket.swift               The 1 → Stake course and labels
    GameState.swift            Per-ball state + Codable persistence model
  ViewModels/
    GameStore.swift            Observable game state + UserDefaults storage
  Views/
    ContentView.swift          Top-level screen
    DeadnessBoardView.swift    Tappable deadness grid
    BallTrackerView.swift      Per-ball card (player, wicket, Scored)
    SettingsView.swift         Team names + reset
    BallChip.swift             Reusable colored ball marker
  Assets.xcassets/             App icon + accent color
```

## Notes / possible next steps

- Deadness is currently fully manual (tap to toggle) plus auto-cleared on a
  scored wicket. Tracking turn-by-turn roquets to compute deadness
  automatically would be a natural follow-up.
- 6-ball play, saved game history, and a turn timer were considered but left
  out of this first version to keep it focused on at-the-lawn scoring.
